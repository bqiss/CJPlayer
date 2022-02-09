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

    AudioDescription audioDesc;

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
    if (m_formatContext ==  NULL) {
        return;
    }
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

        audioDesc = {0};
        audioDesc.asbd = [self getAudioStreamBasicDescriptionFromCodepar:m_audioCodecContext];
        audioDesc.frameSize = m_audioCodecContext -> frame_size;
        int out_linesize;
        int out_buffer_size = av_samples_get_buffer_size(&out_linesize,
                                                         m_audioCodecContext->channels,
                                                         m_audioCodecContext->frame_size,
                                                         m_audioCodecContext->sample_fmt,
                                                         1);
        audioDesc.out_linesize = out_linesize;
        audioDesc.out_buffer_size = out_buffer_size;
}

#pragma mark - Public
- (void)startDecodeAudioDataWithAVPacket:(MyPacket )packet {
    [self startDecodeAudioDataWithAVPacket:packet
                                audioDesc:&audioDesc
                         audioCodecContext:m_audioCodecContext
                                audioFrame:m_audioFrame
                          audioStreamIndex:m_audioStreamIndex];
}

- (void)stopDecoder {
    _delegate = nil;
    [self freeAllResources];
}

- (void)resetIsFirstFrame {
    m_isFirstFrame = YES;
}

- (struct AudioDescription)getAudioDesc {
    return audioDesc;
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

- (void)startDecodeAudioDataWithAVPacket:(MyPacket)myPacket audioDesc:(AudioDescription *)audioDesc audioCodecContext:(AVCodecContext *)audioCodecContext audioFrame:(AVFrame *)audioFrame  audioStreamIndex:(int)audioStreamIndex {

    packetSerial = myPacket.serial;
    AVPacket packet = myPacket.packet;


    //    AudioStreamBasicDescription asbd = [self getAudioStreamBasicDescriptionFromCodepar:audioCodecContext];
    //    AudioData audioInfo = {0};
    //    audioInfo.data = packet.data;
    //    audioInfo.size = packet.size;
    //    audioInfo.asbd = &asbd;
    //    audioInfo.pts = packet.pts* av_q2d(m_formatContext->streams[audioStreamIndex]->time_base);
    //    audioInfo.duration = packet.duration* av_q2d(m_formatContext->streams[audioStreamIndex]->time_base);
    //    audioInfo.frameSize = audioCodecContext -> frame_size;
    //    audioInfo.serial = myPacket.serial;
    int result = avcodec_send_packet(audioCodecContext, &packet);

    if (result < 0) {

        NSLog(@"end audio data to decoder failed.");
    }else {
        pthread_mutex_lock(&_decoder_lock);
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
            uint8_t *out_buffer = (uint8_t *)av_malloc(audioDesc -> out_buffer_size);
            // 转码
            swr_convert(au_convert_ctx, &out_buffer, audioDesc -> out_linesize, (const uint8_t **)audioFrame->data , audioFrame->nb_samples);
            swr_free(&au_convert_ctx);
            au_convert_ctx = NULL;

            uint8_t *audio_data = (uint8_t *)malloc(audioDesc -> out_linesize);

            memcpy(audio_data, out_buffer, audioDesc -> out_linesize);

            audioData.data = audio_data;
            audioData.size = audioDesc -> out_linesize;

            audioData.pts = ptsSec;
            audioData.duration = duration;
            audioData.serial = myPacket.serial;

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
    }
    pthread_mutex_unlock(&_decoder_lock);
}

-(AudioStreamBasicDescription)getAudioStreamBasicDescriptionFromCodepar:(AVCodecContext *)codecPar{
//    AudioStreamBasicDescription asbd = {0};
//    asbd.mSampleRate = codecPar -> sample_rate;
//
//    asbd.mFormatID = kAudioFormatLinearPCM;
//    asbd.mChannelsPerFrame = codecPar -> channels;
//    asbd.mFramesPerPacket = 1;
//    asbd.mFormatFlags        = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
//
////
//    if ((codecPar->format) & (1<<12))
//        asbd.mFormatFlags |= kLinearPCMFormatFlagIsBigEndian;
//    if ((codecPar->format) & (1<<8))
//        asbd.mFormatFlags |= kLinearPCMFormatFlagIsFloat;
//    if ((codecPar->format) & (1<<15))
//        asbd.mFormatFlags |= kLinearPCMFormatFlagIsSignedInteger;
//
//    asbd.mBytesPerFrame = asbd.mBitsPerChannel * asbd.mChannelsPerFrame / 8;
//    asbd.mBytesPerPacket = asbd.mBytesPerFrame * asbd.mFramesPerPacket;
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
        .mChannelsPerFrame   = 2,
        .mFormatFlags        = 12,
        .mBitsPerChannel     = 16,
        .mBytesPerPacket     = 4,
        .mBytesPerFrame      = 4,
        .mFramesPerPacket    = 1,
    };
    return ffmpegAudioFormat;
}

- (void)freeAllResources {
    pthread_mutex_lock(&_decoder_lock);
    if (m_audioCodecContext) {
        avcodec_send_packet(m_audioCodecContext, NULL);
//        avcodec_flush_buffers(m_audioCodecContext);

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

    pthread_mutex_unlock(&_decoder_lock);
}

#pragma mark - Other

@end
