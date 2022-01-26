//
//  CJDecoder.m
//  DecodeByVideoToolBox
//
//  Created by 陈剑 on 2021/12/22.
//

#import "CJDecoderManager.h"


@interface CJDecoderManager()<VideoToolBoxDecoderDeltegate,CJAudioDecoderDelegate>
{
    AVFormatContext *avFormatContext;
    AudioStreamBasicDescription asbd;
}

/* decoder */
@property (nonatomic, strong) FFmpegParseHandler *parseHandler;
@property (nonatomic, strong) VideoToolBoxDecoder *vtDecoder;
@property (nonatomic, strong) CJAudioDecoder *audioDecoder;


@end

@implementation CJDecoderManager

#pragma mark init
- (instancetype)initWithFilePath: (NSString *)path videoState:(VideoState *)videoState {
    if (self = [super init]) {
        self.parseHandler = [[FFmpegParseHandler alloc]initWithPath:path videoState:videoState];
        avFormatContext = [self.parseHandler getFormatContext];
//        self.videoDuration = avFormatContext -> duration;

        self.vtDecoder = [[VideoToolBoxDecoder alloc]init];
        self.vtDecoder.delegate = self;

        self.audioDecoder = [[CJAudioDecoder alloc]initWithFormatContext:avFormatContext audioStreamIndex:[self.parseHandler getAudioStreamIndex]];
        self.audioDecoder.delegate = self;
//        self.videoPacketQueue = [[PacketQueue alloc]init];
//        self.audioPacketQueue = [[PacketQueue alloc]init];


        AudioStreamBasicDescription ffmpegAudioFormat = {
            .mSampleRate         = 48000,
            .mFormatID           = kAudioFormatLinearPCM,
            .mChannelsPerFrame   = 2,
            .mFormatFlags        = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            .mBitsPerChannel     = 16,
            .mBytesPerPacket     = 4,
            .mBytesPerFrame      = 4,
            .mFramesPerPacket    = 1,
        };

        asbd = ffmpegAudioFormat;
    }
    return self;
}

#pragma mark Public Method
- (void)startDecodeAudioDataWithAVPacket:(MyPacket)packet {
    [self.audioDecoder startDecodeAudioDataWithAVPacket:packet];
    av_packet_unref(&packet.packet);
}

- (void)startDecodeVideo:(MyPacket)myPacket {
    AVPacket packet = myPacket.packet;
    struct XDXParseVideoDataInfo videoInfo = [self.parseHandler parseVideoPacket:packet];
    av_packet_unref(&packet);
    videoInfo.serial = myPacket.serial;
     [self.vtDecoder startDecodeVideoData:&videoInfo];
    free(videoInfo.data);
    free(videoInfo.extraData);
}
- (void)DecodeRTMPStream {

}

- (void)startDecode:(VideoState *)videoState videoPakcetQueue:(PacketQueue *)videoPacketQueue audioPacketQueue:(PacketQueue *)audioPacketQueue{

    [self.parseHandler readFile:videoPacketQueue audioPacketQueue:audioPacketQueue videoState:videoState];

//    dispatch_async(dispatch_queue_create("audioDecodeQueue", DISPATCH_QUEUE_SERIAL), ^{
//        for(;;) {
//
//            if (!videoState -> audioRendererIsReadyForMoreData) {
//                av_usleep(10000);
//                continue;
//            }
//
//            MyPacket myPacket;
//            if ([self.audioPacketQueue packet_queue_get:&myPacket]) {
//
//                //if finish
//                if (myPacket.packet.data == NULL) {
//                    break;
//                }
//
//                //if seek;
//                if (myPacket.packet.data == flushPacket.data) {
//                    continue;
//                }
//
//                [self.audioDecoder startDecodeAudioDataWithAVPacket:myPacket];
//                av_packet_unref(&myPacket.packet);
//            }else {
//                av_usleep(10000);
//            }
//        }
//    });
//
//    dispatch_async(dispatch_queue_create("videoDecodeQueue", DISPATCH_QUEUE_SERIAL), ^{
//        for(;;) {
//
//            if (!videoState -> videoRendererIsReadyForMoreData) {
//                av_usleep(10000);
//                continue;
//            }
//
//            if (self.parseHandler.isPause) {
//                break;
//            }
//
//            MyPacket myPacket;
//            if ([self.videoPacketQueue packet_queue_get:&myPacket]) {
//                AVPacket packet = myPacket.packet;
//
//                if (packet.data == NULL) {
//                    break;
//                }
//
//                //if seek;
//                if (myPacket.packet.data == flushPacket.data) {
//                    continue;
//                }
//                struct XDXParseVideoDataInfo videoInfo = [self.parseHandler parseVideoPacket:packet];
//                av_packet_unref(&packet);
//                videoInfo.serial = myPacket.serial;
//                 [self.vtDecoder startDecodeVideoData:&videoInfo];
//                free(videoInfo.data);
//                free(videoInfo.extraData);
//            } else {
//
//                //if queue is empty wait 10ms
//                av_usleep(10000);
//            }
//        }
//    });
}

- (void)seekToTime:(Float64) stampTime {
    [self.parseHandler upDateAvContextFormatFromSeekTimeStamp:stampTime];
    [self.parseHandler seekRequest];
}

- (void)pauseDecoder {
    self.parseHandler.isPause = YES;
}

- (void)startDecoder {
    self.parseHandler.isPause = NO;
}


- (AVFormatContext *)getFormatContext {
    return [self.parseHandler getFormatContext];
}

- (void)stopParsehandler {
    [self.parseHandler stopParse];
}
#pragma mark private method
#pragma mark delegate method
-(void)getVideoDecodeDataByVideoToolBox:(MySampleBuffer *)samplebuffer {
    if (_delegate && [_delegate respondsToSelector:@selector(CJDecoderGetVideoSampleBufferCallback:)]) {
        [_delegate CJDecoderGetVideoSampleBufferCallback:samplebuffer];
    }
//    mach_msg(<#mach_msg_header_t *msg#>, <#mach_msg_option_t option#>, <#mach_msg_size_t send_size#>, <#mach_msg_size_t rcv_size#>, <#mach_port_name_t rcv_name#>, <#mach_msg_timeout_t timeout#>, <#mach_port_name_t notify#>)
}

- (void)getAudioDecodeDataByFFmpeg:(struct AudioData *)audioData serial:(int)serial isFirstFrame:(BOOL)isFirstFrame {
    CMSampleBufferRef sampleBuffer = [self createAudioSampleBuffer:audioData];
    if (_delegate && [_delegate respondsToSelector:@selector(CJDecoderGetAudioSampleBufferCallback: isFirstFrame:)]) {
        MySampleBuffer mySamplebuffer = {0};
        mySamplebuffer.sampleBuffer = sampleBuffer;
        mySamplebuffer.serial = audioData -> serial;

        [_delegate CJDecoderGetAudioSampleBufferCallback:&mySamplebuffer isFirstFrame:isFirstFrame];
    }
    CFRelease(sampleBuffer);
}

#pragma mark other
- (CMSampleBufferRef)createAudioSampleBuffer:(struct AudioData * )audioInfo{

    AudioBufferList audioData;
    audioData.mNumberBuffers = 1;
    uint8_t * tmp = malloc(audioInfo -> size);
    memcpy(tmp, audioInfo -> data, audioInfo -> size);

    AudioStreamBasicDescription * asbd = audioInfo -> asbd;

    audioData.mBuffers[0].mData = tmp;
    audioData.mBuffers[0].mNumberChannels = asbd -> mBitsPerChannel;
    audioData.mBuffers[0].mDataByteSize = audioInfo -> size;

    CMBlockBufferRef blockBuffer = [self makeBlockBuffer:&audioData];

    CMSampleBufferRef sampleBuffer = NULL;
    CMFormatDescriptionRef format =NULL;
    OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, asbd,0, NULL, 0, NULL, NULL, &format);

    status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(kCFAllocatorDefault, blockBuffer, format, audioInfo -> frameSize, CMTimeMakeWithSeconds(audioInfo -> pts, asbd -> mSampleRate), nil, &sampleBuffer);


    if (status != noErr) {
        NSLog(@"CMAudioSampleBufferCreateReadyWithPacketDescriptions fail!");
    }

    if (format != NULL) {
        CFRelease(format);
    }

    if (blockBuffer != NULL) {
        CFRelease(blockBuffer);
    }

    free(tmp);
    tmp = NULL;
    return sampleBuffer;
}

- (CMBlockBufferRef)makeBlockBuffer:(AudioBufferList *)audioListBuffer {
    OSStatus status;
    CMBlockBufferRef outBlockListBuffer =  nil;

    status = CMBlockBufferCreateEmpty(kCFAllocatorDefault, 0, 0, &outBlockListBuffer);

    CMBlockBufferRef blockListBuffer = outBlockListBuffer;
    if (status != noErr) {
        NSLog(@"emptyBlock create fail!");
    }

    for (int i = 0; i < audioListBuffer -> mNumberBuffers; i++) {
        AudioBuffer audioBuffer = audioListBuffer -> mBuffers[i];
        CMBlockBufferRef outBlockBuffer = nil;
        int dataByteSize = (int)audioBuffer.mDataByteSize;

        status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, nil, dataByteSize, kCFAllocatorDefault, nil, 0, dataByteSize, kCMBlockBufferAssureMemoryNowFlag, &outBlockBuffer);

        if (status != noErr) {
            NSLog(@"CMBlockBufferCreateWithMemoryBlock error");
        }
        CMBlockBufferRef blockBuffer = outBlockBuffer;

        status = CMBlockBufferReplaceDataBytes(audioBuffer.mData, blockBuffer, 0, dataByteSize);

        if (status != noErr) {
            NSLog(@"CMBlockBufferReplaceDataBytes error");
        }

        status = CMBlockBufferAppendBufferReference(blockListBuffer, blockBuffer, 0, CMBlockBufferGetDataLength(blockBuffer), 0);

        if (status != noErr) {
            NSLog(@"CMBlockBufferAppendBufferReference error");
        }

        if (outBlockBuffer != NULL) {
            CFRelease(outBlockBuffer);
        }
    }
    return blockListBuffer;
}
@end
