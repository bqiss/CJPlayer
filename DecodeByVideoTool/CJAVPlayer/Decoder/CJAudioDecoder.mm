//
//  CJAudioDecoder.m
//  DecodeByVideoToolBox
//
//  Created by 陈剑 on 2021/12/27.
//

#import "CJAudioDecoder.h"

#define MAX_AUDIO_FRAME_SIZE  192000
static int packetSerial = 0;

@interface CJAudioDecoder()
{
    /*  FFmpeg  */
    AVFormatContext          *m_formatContext;
    AVCodecContext           *m_audioCodecContext;
    AVFrame                  *m_audioFrame;

    int     m_audioStreamIndex;
    BOOL    m_isFindIDR;
    int64_t m_base_time;
    BOOL    m_isFirstFrame;

    pthread_mutex_t _decoder_lock;

}
@end
@implementation CJAudioDecoder
- (instancetype)initWithFormatContext:(AVFormatContext *)formatContext audioStreamIndex:(int)audioStreamIndex{
    if (self = [super init]) {
        m_formatContext     = formatContext;
        m_audioStreamIndex  = audioStreamIndex;

        m_isFindIDR      = NO;
        m_base_time      = 0;
        m_isFirstFrame   = YES;
        pthread_mutex_init(&_decoder_lock, NULL);
        [self initDecoder];
    }
    return self;
}

- (void)initDecoder {
    AVStream *audioStream = m_formatContext->streams[m_audioStreamIndex];
    m_audioCodecContext = [self createAudioEncderWithFormatContext:m_formatContext
                                                            stream:audioStream
                                                  audioStreamIndex:m_audioStreamIndex];
    if (!m_audioCodecContext) {
        NSLog(@"create audio codec failed");
        return;
    }

    // Get audio frame 
    m_audioFrame = av_frame_alloc();
    if (!m_audioFrame) {
        NSLog(@"alloc audio frame failed");
        avcodec_close(m_audioCodecContext);
    }
}

#pragma mark - Public
- (void)startDecodeAudioDataWithAVPacket:(MyPacket )packet {
    [self startDecodeAudioDataWithAVPacket:packet
                         audioCodecContext:m_audioCodecContext
                                audioFrame:m_audioFrame
                          audioStreamIndex:m_audioStreamIndex];
}

- (void)stopDecoder {
    m_isFirstFrame  = YES;
    [self freeAllResources];
}
- (void)resetIsFirstFrame {
    m_isFirstFrame = YES;
}

#pragma mark Private
- (AVCodecContext *)createAudioEncderWithFormatContext:(AVFormatContext *)formatContext stream:(AVStream *)stream audioStreamIndex:(int)audioStreamIndex {
    AVCodecContext *codecContext = formatContext->streams[audioStreamIndex]->codec;
    AVCodec *codec = avcodec_find_decoder(codecContext->codec_id);
    if (!codec) {
        NSLog(@"Not find audio codec");
        return NULL;
    }

    if (avcodec_open2(codecContext, codec, NULL) < 0) {
        NSLog(@"Can't open audio codec");
        return NULL;
    }

    return codecContext;
}

- (void)startDecodeAudioDataWithAVPacket:(MyPacket)myPacket audioCodecContext:(AVCodecContext *)audioCodecContext audioFrame:(AVFrame *)audioFrame  audioStreamIndex:(int)audioStreamIndex {

//    pthread_mutex_lock(&_decoder_lock);
    packetSerial = myPacket.serial;
    AVPacket packet = myPacket.packet;
    int result = avcodec_send_packet(audioCodecContext, &packet);

    if (result < 0) {

        NSLog(@"end audio data to decoder failed.");
    }else {
        while (0 == avcodec_receive_frame(audioCodecContext, audioFrame)) {
            AudioData audioData = {0};
            AVCodecParameters *avcodecpar = m_formatContext -> streams[audioStreamIndex] -> codecpar;
            
            Float64 ptsSec = audioFrame->pts* av_q2d(m_formatContext->streams[audioStreamIndex]->time_base);


            Float64 duration = audioFrame->pkt_duration* av_q2d(m_formatContext->streams[audioStreamIndex]->time_base);
        
            struct SwrContext *au_convert_ctx = swr_alloc();
            au_convert_ctx = swr_alloc_set_opts(au_convert_ctx,
                                                AV_CH_LAYOUT_STEREO,
                                                AV_SAMPLE_FMT_S16,
                                                avcodecpar -> sample_rate,
                                                audioCodecContext->channel_layout,
                                                audioCodecContext->sample_fmt,
                                                audioCodecContext->sample_rate,
                                                0,
                                                NULL);
            swr_init(au_convert_ctx);
            int out_linesize;
            int out_buffer_size = av_samples_get_buffer_size(&out_linesize,
                                                             audioCodecContext->channels,
                                                             audioCodecContext->frame_size,
                                                             audioCodecContext->sample_fmt,
                                                             1);

            uint8_t *out_buffer = (uint8_t *)av_malloc(out_buffer_size);
            // 转码
            swr_convert(au_convert_ctx, &out_buffer, out_linesize, (const uint8_t **)audioFrame->data , audioFrame->nb_samples);
            swr_free(&au_convert_ctx);
            au_convert_ctx = NULL;

            uint8_t *audio_data = (uint8_t *)malloc(out_linesize);

            memcpy(audio_data, out_buffer, out_linesize);

            AudioStreamBasicDescription asbd = [self getAudioStreamBasicDescriptionFromCodepar:avcodecpar];

            audioData.data = audio_data;
            audioData.size = out_linesize;
            audioData.frameSize = avcodecpar -> frame_size;
            audioData.pts = ptsSec;
            audioData.duration = duration;
            audioData.asbd = &asbd;
            audioData.isNeedReseTimebase = myPacket.isNeedResetTimeBase;


            if ([self.delegate respondsToSelector:@selector(getAudioDecodeDataByFFmpeg:serial:isFirstFrame:)]) {
                [self.delegate getAudioDecodeDataByFFmpeg:&audioData serial:packetSerial isFirstFrame:m_isFirstFrame];
                m_isFirstFrame=NO;
            }

            av_free(audio_data);
            av_frame_unref(audioFrame);
            av_free(out_buffer);
        }

        if (result != 0) {
            NSLog(@"Decode finish");
        }
//        pthread_mutex_unlock(&_decoder_lock);
    }
}

-(AudioStreamBasicDescription)getAudioStreamBasicDescriptionFromCodepar:(AVCodecParameters *)codecPar{
    AudioStreamBasicDescription asbd = {0};
    asbd.mSampleRate = codecPar -> sample_rate;

    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mChannelsPerFrame = codecPar -> channels;
    asbd.mFramesPerPacket = 1;
    asbd.mFormatFlags        = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;

//
    if ((codecPar->format) & (1<<12))
        asbd.mFormatFlags |= kLinearPCMFormatFlagIsBigEndian;
    if ((codecPar->format) & (1<<8))
        asbd.mFormatFlags |= kLinearPCMFormatFlagIsFloat;
    if ((codecPar->format) & (1<<15))
        asbd.mFormatFlags |= kLinearPCMFormatFlagIsSignedInteger;
//
    asbd.mBytesPerFrame = asbd.mBitsPerChannel * asbd.mChannelsPerFrame / 8;
    asbd.mBytesPerPacket = asbd.mBytesPerFrame * asbd.mFramesPerPacket;
//    AudioStreamBasicDescription destinationFormat = {0};
//    destinationFormat.mSampleRate = 48000;
//    destinationFormat.mChannelsPerFrame  = 1;
//    destinationFormat.mFormatID          = kAudioFormatLinearPCM;
//    destinationFormat.mFormatFlags       = (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked);
//    destinationFormat.mFramesPerPacket   = 1;
//    destinationFormat.mBitsPerChannel    = 16;
//    destinationFormat.mBytesPerFrame     = destinationFormat.mBitsPerChannel / 8 *destinationFormat.mChannelsPerFrame;
//    destinationFormat.mBytesPerPacket    = destinationFormat.mBytesPerFrame * destinationFormat.mFramesPerPacket;
//    destinationFormat.mReserved          =  0;
    Float64 sampleRate = codecPar -> sample_rate;
    AudioStreamBasicDescription ffmpegAudioFormat = {
        .mSampleRate         =  sampleRate,
        .mFormatID           = kAudioFormatLinearPCM,
        .mChannelsPerFrame   = static_cast<UInt32>(codecPar -> channels),
        .mFormatFlags        = 12,
        .mBitsPerChannel     = 16,
        .mBytesPerPacket     = 4,
        .mBytesPerFrame      = 4,
        .mFramesPerPacket    = 1,
    };
    return ffmpegAudioFormat;
}

- (void)freeAllResources {
    if (m_audioCodecContext) {
        avcodec_send_packet(m_audioCodecContext, NULL);
        avcodec_flush_buffers(m_audioCodecContext);

        if (m_audioCodecContext->hw_device_ctx) {
            av_buffer_unref(&m_audioCodecContext->hw_device_ctx);
            m_audioCodecContext->hw_device_ctx = NULL;
        }
        avcodec_close(m_audioCodecContext);
        m_audioCodecContext = NULL;
    }

    if (m_audioFrame) {
        av_free(m_audioFrame);
        m_audioFrame = NULL;
    }
}

#pragma mark - Other

@end
