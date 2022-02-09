//
//  FFmpegParseHandler.m
//  DecodeByVideoToolBox
//
//  Created by 陈剑 on 2021/12/15.
//
//

#import "FFmpegParseHandler.h"


#pragma mark - Global Var

#define MAX_QUEUE_SIZE (15 * 1024 * 1024)



static const int kXDXParseSupportMaxFps     = 60;
static const int kXDXParseFpsOffSet         = 5;
static const int kXDXParseWidth1920         = 1920;
static const int kXDXParseHeight1080        = 1080;
static const int kXDXParseSupportMaxWidth   = 3840;
static const int kXDXParseSupportMaxHeight  = 2160;
static int serial = 0;

@interface FFmpegParseHandler ()
{
    /*  Flag  */
    BOOL m_isStopParse;
    BOOL m_isSeekFile;

    //seek
    int64_t seekTimeStamp;

    /*  FFmpeg  */
    AVFormatContext          *m_formatContext;
    AVBitStreamFilterContext *m_bitFilterContext;
//    AVBSFContext             *m_bsfContext;

    int m_videoStreamIndex;
    int m_audioStreamIndex;

    /*  Video info  */
    int m_video_width, m_video_height, m_video_fps;
    int64_t videoDuration;

    dispatch_queue_t parseQueue;
    bool seekReqest;
    Float64 seekTime;

    pthread_mutex_t mutex;
    PacketQueue *videoQueue;
    PacketQueue *audioQueue;
}

@end

@implementation FFmpegParseHandler

#pragma mark - C Function
static int GetAVStreamFPSTimeBase(AVStream *st) {
    CGFloat fps, timebase = 0.0;

    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->codec->time_base.den && st->codec->time_base.num)
        timebase = av_q2d(st->codec->time_base);

    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;

    
    return fps;
}

#pragma mark - Init
+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        av_register_all();
    });
}

- (instancetype)initWithPath:(NSString *)path videoState:(VideoState *)videoState {
    if (self = [super init]) {
        parseQueue = dispatch_queue_create("parse_queue", DISPATCH_QUEUE_SERIAL);
        pthread_mutex_init(&mutex, NULL);
        if (![self prepareParseWithPath:path]) {
            return nil;
        }
    }
    return self;
}

#pragma mark - public methods
- (void)destroyParseHandler {
    pthread_mutex_lock(&mutex);
    m_isStopParse = YES;
    [self freeAllResources];
    [audioQueue packet_queue_destroy];
    [videoQueue packet_queue_destroy];
    pthread_mutex_unlock(&mutex);
}
#pragma mark Get Method
- (AVFormatContext *)getFormatContext {
    return m_formatContext;
}

- (AVBitStreamFilterContext *)getBitStreamFilter {
    return m_bitFilterContext;
}

- (int)getVideoStreamIndex {
    return m_videoStreamIndex;
}

- (int)getAudioStreamIndex {
    return m_audioStreamIndex;
}

#pragma mark - Private
#pragma mark Prepare
- (int)prepareParseWithPath:(NSString *)path {
    


    // Create format context
    m_formatContext = [self createFormatContextbyFilePath:path];

    
    if (m_formatContext == NULL) {
        return 0;
    }

    // Get video stream index
    m_videoStreamIndex = [self getAVStreamIndexWithFormatContext:m_formatContext
                                                   isVideoStream:YES];

    // Get video stream
    AVStream *videoStream = m_formatContext->streams[m_videoStreamIndex];
    m_video_width  = videoStream->codecpar->width;
    m_video_height = videoStream->codecpar->height;
    m_video_fps    = GetAVStreamFPSTimeBase(videoStream);

    BOOL isSupport = [self isSupportVideoStream:videoStream
                                  formatContext:m_formatContext
                                    sourceWidth:m_video_width
                                   sourceHeight:m_video_height
                                      sourceFps:m_video_fps];
    if (!isSupport) {
        NSLog(@"Not support the video stream");
        return 1;
    }

    // Get audio stream index
    m_audioStreamIndex = [self getAVStreamIndexWithFormatContext:m_formatContext
                                                   isVideoStream:NO];

    // Get audio stream
    AVStream *audioStream = m_formatContext->streams[m_audioStreamIndex];

    isSupport = [self isSupportAudioStream:audioStream
                             formatContext:m_formatContext];
    if (!isSupport) {
        NSLog(@"Not support the audio stream");
        return 1;
    }
    return 1;
}

- (AVFormatContext *)createFormatContextbyFilePath:(NSString *)filePath {
    if (filePath == nil) {
        //log4cplus_error(kModuleName, "%s: file path is NULL",__func__);
        return NULL;
    }
    avformat_network_init();
    AVFormatContext *formatContext = NULL;
    AVDictionary     *opts          = NULL;

    const char *infile_name = [filePath UTF8String];

      if (av_stristart(infile_name, "http", NULL) ||
        av_stristart(infile_name, "https", NULL)) {
        // There is total different meaning for 'timeout' option in rtmp

        av_dict_set(&opts, "timeout", "2000000", 0);//设置超时2秒
    }

    if (av_stristart(infile_name, "rtmp", NULL) ||
        av_stristart(infile_name, "rtsp", NULL)) {
        // There is total different meaning for 'timeout' option in rtmp
        avformat_network_init();
        av_dict_set(&opts, "timeout", NULL, 0);


    }else {
        av_dict_set(&opts, "timeout", "1000000", 0);//设置超时1秒
    }

    formatContext = avformat_alloc_context();
    BOOL isSuccess = avformat_open_input(&formatContext, [filePath cStringUsingEncoding:NSUTF8StringEncoding], NULL, &opts) < 0 ? NO : YES;
    av_dict_free(&opts);
    if (!isSuccess) {
        if (formatContext) {
            avformat_free_context(formatContext);
        }
        return NULL;
    }

    if (avformat_find_stream_info(formatContext, NULL) < 0) {
        avformat_close_input(&formatContext);
        return NULL;
    }

    return formatContext;
}

- (int)getAVStreamIndexWithFormatContext:(AVFormatContext *)formatContext isVideoStream:(BOOL)isVideoStream {
    int avStreamIndex = -1;
    for (int i = 0; i < formatContext->nb_streams; i++) {
        if ((isVideoStream ? AVMEDIA_TYPE_VIDEO : AVMEDIA_TYPE_AUDIO) == formatContext->streams[i]->codecpar->codec_type) {
            avStreamIndex = i;
        }
    }

    if (avStreamIndex == -1) {
       // log4cplus_error(kModuleName, "%s: Not find video stream",__func__);
        return NULL;
    }else {
        return avStreamIndex;
    }
}

- (BOOL)isSupportVideoStream:(AVStream *)stream formatContext:(AVFormatContext *)formatContext sourceWidth:(int)sourceWidth sourceHeight:(int)sourceHeight sourceFps:(int)sourceFps {
    if (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {   // Video
        AVCodecID codecID = stream->codecpar->codec_id;

        // 目前只支持H264、H265(HEVC iOS11)编码格式的视频文件
        if ((codecID != AV_CODEC_ID_H264 && codecID != AV_CODEC_ID_HEVC) || (codecID == AV_CODEC_ID_HEVC && [[UIDevice currentDevice].systemVersion floatValue] < 11.0)) {

            return NO;
        }

        // iPhone 8以上机型支持有旋转角度的视频
        AVDictionaryEntry *tag = NULL;
        tag = av_dict_get(formatContext->streams[m_videoStreamIndex]->metadata, "rotate", tag, 0);
        if (tag != NULL) {
            int rotate = [[NSString stringWithFormat:@"%s",tag->value] intValue];
            if (rotate != 0 /* && >= iPhone 8P*/) {

            }
        }

        /*
         各机型支持的最高分辨率和FPS组合:

         iPhone 6S: 60fps -> 720P
         30fps -> 4K

         iPhone 7P: 60fps -> 1080p
         30fps -> 4K

         iPhone 8: 60fps -> 1080p
         30fps -> 4K

         iPhone 8P: 60fps -> 1080p
         30fps -> 4K

         iPhone X: 60fps -> 1080p
         30fps -> 4K

         iPhone XS: 60fps -> 1080p
         30fps -> 4K
         */

        // 目前最高支持到60FPS
        if (sourceFps > kXDXParseSupportMaxFps + kXDXParseFpsOffSet) {

            return NO;
        }

        // 目前最高支持到3840*2160
        if (sourceWidth > kXDXParseSupportMaxWidth || sourceHeight > kXDXParseSupportMaxHeight) {

            return NO;
        }

        // 60FPS -> 1080P
        if (sourceFps > kXDXParseSupportMaxFps - kXDXParseFpsOffSet && (sourceWidth > kXDXParseWidth1920 || sourceHeight > kXDXParseHeight1080)) {

            return NO;
        }

        // 30FPS -> 4K
        if (sourceFps > kXDXParseSupportMaxFps / 2 + kXDXParseFpsOffSet && (sourceWidth >= kXDXParseSupportMaxWidth || sourceHeight >= kXDXParseSupportMaxHeight)) {

            return NO;
        }

        return YES;
    }else {
        return NO;
    }

}

- (BOOL)isSupportAudioStream:(AVStream *)stream formatContext:(AVFormatContext *)formatContext {
    if (stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
        AVCodecID codecID = stream->codecpar->codec_id;
        // 本项目只支持AAC格式的音频
        if (codecID != AV_CODEC_ID_AAC) {
            return NO;
        }

        return YES;
    }else {
        return NO;
    }
}

#pragma mark Start Parse
- (void)readFile:(PacketQueue *)videoPacketQueue audioPacketQueue:(PacketQueue *)audioPacketQueue videoState:(VideoState *)videoState {

    videoQueue = videoPacketQueue;
    audioQueue = audioPacketQueue;
    m_formatContext -> interrupt_callback.callback = custom_interrupt_callback;
    m_formatContext -> interrupt_callback.opaque = videoState;

    __block BOOL isNeedThrowPacket;

    dispatch_async(parseQueue, ^{
        pthread_mutex_lock(&self -> mutex);
        AVPacket    packet;
        for (;;) {
            int ret;

            if (videoState -> quit) {
                break;
            }
            
            if (videoState -> isSeekReq) {
                ret = av_seek_frame(self->m_formatContext, -1, videoState -> seekTimeStamp * AV_TIME_BASE, AVSEEK_FLAG_BACKWARD);
                if (ret < 0) {
                    NSLog(@"error while seeking!");
                    break;
                }
                [videoPacketQueue packet_queue_flush];
                [audioPacketQueue packet_queue_flush];
                MyPacket myPacket = {0};
                myPacket.packet = flushPacket;
                [videoPacketQueue packet_queue_put:&myPacket];
                [audioPacketQueue packet_queue_put:&myPacket];
                videoState -> isSeekReq = NO;
                videoState -> parseEnd = NO;
                isNeedThrowPacket = YES;

            }


            if ([videoPacketQueue getQueueSize] + [audioPacketQueue getQueueSize] > MAX_QUEUE_SIZE) {

                /* wait  10ms */
                av_usleep(10000);
                continue;
            }

            av_init_packet(&packet);


            ret = av_read_frame(self->m_formatContext, &packet);
            if (ret < 0) {
                int pb_eof = 0;
                int pb_error = 0;
                if ((ret == AVERROR_EOF || avio_feof(self -> m_formatContext->pb)) && !videoState -> parseEnd) {
                    pb_eof = 1;
                }

                if (self -> m_formatContext->pb && self -> m_formatContext->pb->error) {
                    pb_eof = 1;
                    pb_error = self -> m_formatContext->pb->error;
                }
                if (ret == AVERROR_EXIT) {
                    pb_eof = 1;
                    pb_error = AVERROR_EXIT;
                }

                if (pb_eof) {
                    if (self -> m_videoStreamIndex >= 0)
                        [videoPacketQueue packet_queue_put_nullpacket:self->m_videoStreamIndex];
                    if (self -> m_audioStreamIndex >= 0)
                        [audioPacketQueue packet_queue_put_nullpacket:self->m_audioStreamIndex];
                    videoState -> parseEnd = 1;
                }

                if (pb_error) {
                    if (self -> m_videoStreamIndex >= 0)
                        [videoPacketQueue packet_queue_put_nullpacket:self->m_videoStreamIndex];
                    if (self -> m_audioStreamIndex >= 0)
                        [audioPacketQueue packet_queue_put_nullpacket:self->m_audioStreamIndex];
                    videoState -> parseEnd = 1;
                    printf("read frame error!\n");
                    break;
                }

                if (videoState -> parseEnd) {
                    av_usleep(10000);
                }
            }

            if (packet.stream_index == self->m_videoStreamIndex) {
                MyPacket myPacket = {0};
                if (isNeedThrowPacket && packet.flags == 0x0010){
                    //NSLog(@"throw video pkt: pkt.pts < seekTimeStamp!");
                    av_packet_unref(&packet);
                    continue;;
                }else if (packet.pts * av_q2d(self -> m_formatContext->streams[self -> m_videoStreamIndex]->time_base) > videoState -> seekTimeStamp){
                    isNeedThrowPacket = NO;
                }
                myPacket.packet = packet;
                [videoPacketQueue packet_queue_put:&myPacket];
                continue;
            }

            if (packet.stream_index == self->m_audioStreamIndex) {
                MyPacket myPacket = {0};
                if (isNeedThrowPacket && packet.pts * av_q2d(self -> m_formatContext->streams[self -> m_audioStreamIndex]->time_base) < videoState -> seekTimeStamp) {
                    av_packet_unref(&packet);
//                    NSLog(@"throw audio pkt: pkt.pts < seekTimeStamp!");
                    continue;
                }
                myPacket.packet = packet;
                [audioPacketQueue packet_queue_put:&myPacket];
                continue;
            }
        }
        pthread_mutex_unlock(&self -> mutex);
    });

}

- (struct ParseVideoDataInfo)parseVideoPacket: (AVPacket)packet{
    ParseVideoDataInfo videoInfo = {0};

    if (packet.data == flushPacket.data) {
        videoInfo.data = flushPacket.data;
        return videoInfo;
    }
    int fps = GetAVStreamFPSTimeBase(m_formatContext->streams[m_videoStreamIndex]);

    // get the rotation angle of video
    AVDictionaryEntry *tag = NULL;
    AVRational  input_base;
    input_base.num = 1;
    input_base.den = 1000;
    tag = av_dict_get(m_formatContext->streams[m_videoStreamIndex]->metadata, "rotate", tag, 0);
    if (tag != NULL) {
        int rotate = [[NSString stringWithFormat:@"%s",tag->value] intValue];
        switch (rotate) {
            case 90:
                videoInfo.videoRotate = 90;
                break;
            case 180:
                videoInfo.videoRotate = 180;
                break;
            case 270:
                videoInfo.videoRotate = 270;
                break;
            default:
                videoInfo.videoRotate = 0;
                break;
        }
    }

    if (videoInfo.videoRotate != 0 /* &&  <= iPhone 8*/) {

        //break;
    }

    int video_size = packet.size;
    uint8_t *video_data = (uint8_t *)malloc(video_size);

    memcpy(video_data, packet.data, video_size);

    static char filter_name[32];
    if (m_formatContext->streams[m_videoStreamIndex]->codecpar->codec_id == AV_CODEC_ID_H264) {
        strncpy(filter_name, "h264_mp4toannexb", 32);
        videoInfo.videoFormat = H264EncodeFormat;
    } else if (m_formatContext->streams[m_videoStreamIndex]->codecpar->codec_id == AV_CODEC_ID_HEVC) {
        strncpy(filter_name, "hevc_mp4toannexb", 32);
        videoInfo.videoFormat = H265EncodeFormat;
    }

    /* new API can't get correct sps, pps.
    if (!self->m_bsfContext) {
        const AVBitStreamFilter *filter = av_bsf_get_by_name(filter_name);
        av_bsf_alloc(filter, &self->m_bsfContext);
        av_bsf_init(self->m_bsfContext);
        avcodec_parameters_copy(self->m_bsfContext->par_in, formatContext->streams[videoStreamIndex]->codecpar);
    }
    */

    // get sps,pps. If not call it, get sps , pps is incorrect. use new_packet to resolve memory leak.
    AVPacket new_packet = packet;
    if (self->m_bitFilterContext == NULL) {
        self->m_bitFilterContext = av_bitstream_filter_init(filter_name);
    }


    av_bitstream_filter_filter(self->m_bitFilterContext, m_formatContext->streams[m_videoStreamIndex]->codec, NULL, &new_packet.data, &new_packet.size, packet.data, packet.size, 0);

    CMSampleTimingInfo timingInfo;
    CMTime presentationTimeStamp     = kCMTimeInvalid;
    presentationTimeStamp            = CMTimeMakeWithSeconds(packet.pts * av_q2d(m_formatContext->streams[m_videoStreamIndex]->time_base), fps);
    timingInfo.presentationTimeStamp = presentationTimeStamp;
    timingInfo.decodeTimeStamp       = CMTimeMakeWithSeconds( av_rescale_q(packet.dts, m_formatContext->streams[m_videoStreamIndex]->time_base, input_base), fps);

    videoInfo.data          = video_data;
    videoInfo.dataSize      = video_size;
    videoInfo.extraDataSize = m_formatContext->streams[m_videoStreamIndex]->codec->extradata_size;
    videoInfo.extraData     = (uint8_t *)malloc(videoInfo.extraDataSize);
    videoInfo.timingInfo    = timingInfo;
    videoInfo.pts           = packet.pts * av_q2d(m_formatContext->streams[m_videoStreamIndex]->time_base);
    videoInfo.fps           = fps;
    videoInfo.flags         = packet.flags;
    videoInfo.serial        = serial;
    videoInfo.width         = m_formatContext -> streams[m_videoStreamIndex] -> codecpar -> width;
    videoInfo.height        = m_formatContext -> streams[m_videoStreamIndex] -> codecpar -> height;


    memcpy(videoInfo.extraData, m_formatContext->streams[m_videoStreamIndex]->codec->extradata, videoInfo.extraDataSize);
    av_free(new_packet.data);


    return videoInfo;
}



- (void)freeAllResources {
    if (m_formatContext) {
        avformat_close_input(&m_formatContext);
        m_formatContext = NULL;
    }

    if (m_bitFilterContext) {
        av_bitstream_filter_close(m_bitFilterContext);
        m_bitFilterContext = NULL;
    }

//    if (m_bsfContext) {
//        av_bsf_free(&m_bsfContext);
//        m_bsfContext = NULL;
//    }
}

#pragma mark Other

static int custom_interrupt_callback(void *arg) {

    VideoState * videoState = (VideoState *)arg;
    if (videoState -> quit) {
        return 1;
    }

    // do something
    return 0;
}
@end
