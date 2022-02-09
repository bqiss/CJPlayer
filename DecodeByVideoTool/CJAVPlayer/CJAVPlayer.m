//
//  CJAVPlayerItem.m
//  DecodeByVideoTool
//
//  Created by 陈剑 on 2022/1/7.
//

#import "CJAVPlayer.h"


static int rendererSerial = 0;
static int64_t startTime = 0;

@interface CJAVPlayer()<CJDecoderManagerCallDelegate>
{
    AVFormatContext * formatContext;
    dispatch_queue_t queue;
    dispatch_queue_t videoGetBufferQueue;
    dispatch_queue_t audioGetBufferQueue;
    BOOL isSeeking;
    BOOL isRunning;
    BOOL isRestartPlay;
    VideoState *videoState;
    id timeObserve;
    dispatch_queue_t observeQueue;
    CMTime observeIntervalTime;

    pthread_mutex_t audioMutex;
    pthread_mutex_t videoMutex;
}


@property (nonatomic, strong) CJDecoderManager * decoderManager;

@property (nonatomic, strong) AVSampleBufferRenderSynchronizer * rendererSynchronizer;

@property (nonatomic, strong) AVSampleBufferAudioRenderer * audioRenderer;
@property (nonatomic, strong) PacketQueue * videoPacketQueue;
@property (nonatomic, strong) PacketQueue * audioPacketQueue;
@property (nonatomic, copy) void (^handler)(CMTime time);

@property (nonatomic, assign) int rate;

@end

@implementation CJAVPlayer
- (instancetype)initWithURLString:(NSString *)url layerFrame:(CGRect)frame{
    if (self = [super init]) {
        pthread_mutex_init(&audioMutex, NULL);
        pthread_mutex_init(&videoMutex, NULL);
        queue = dispatch_queue_create("playerQueue", DISPATCH_QUEUE_SERIAL);
        videoGetBufferQueue = dispatch_queue_create("videoGetBufferQueue", DISPATCH_QUEUE_SERIAL);
        audioGetBufferQueue = dispatch_queue_create("audioGetBufferQueue", DISPATCH_QUEUE_SERIAL);
        [self initLayerAndAudioRenderer:frame];
        [self preparePlayer:url];
        
    }
    return self;
}

- (void)initLayerAndAudioRenderer: (CGRect)frame {
    self.playLayer = [[CJAVPlaylayer alloc] init];
    self.playLayer.frame = frame;
    self.playLayer.position = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    self.playLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playLayer.opaque = YES;

    self.audioRenderer = [[AVSampleBufferAudioRenderer alloc]init];
    [self.playLayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [self.audioRenderer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    self.videoPacketQueue = [[PacketQueue alloc]init];
    self.audioPacketQueue = [[PacketQueue alloc]init];
}

- (void)preparePlayer:(NSString *)url{

    videoState = malloc(sizeof(VideoState));
    self.decoderManager = [[CJDecoderManager alloc]initWithFilePath:url videoState:videoState];
    self.decoderManager.delegate = self;
    formatContext = [self.decoderManager getFormatContext];

    self.rendererSynchronizer = [[AVSampleBufferRenderSynchronizer alloc]init];
    [self.rendererSynchronizer addRenderer:self.playLayer];
    [self.rendererSynchronizer addRenderer:self.audioRenderer];
    self.rate = 1;
    

}

#pragma  mark Public Method

- (void)pause {
    self.rate = 0;
//    [self.audioRenderer stopRequestingMediaData];
//    [self.playLayer stopRequestingMediaData];
}

- (void)play {
    if (isRestartPlay) {
        isRestartPlay = NO;
        [self seekToTime:0];

    }

    if (!isRunning) {
        [self.decoderManager startDecode:videoState videoPakcetQueue:self.videoPacketQueue audioPacketQueue:self.audioPacketQueue];
        [self restartPlayerAtStartTime:0];
        self.rate = 1;
        isRunning = YES;
    }else {
        if (self.rate != 0) {
            return;
        }
        self.rate = 1;
    }

}

- (void)seekToTime:(Float64)timeStamp {
    if (!isSeeking) {
        NSLog(@"-----seekStart-----:%f",timeStamp);
        rendererSerial++;
        videoState -> isSeekReq = YES;
        videoState -> seekTimeStamp = timeStamp;
        isSeeking = YES;
        [self restartPlayerAtStartTime:timeStamp];
    }
}

- (void)addPeriodicTimeObserverForInterval:(CMTime)time queue:(nonnull dispatch_queue_t)queue usingBlock:(void (^)(CMTime time))handler{
    self.handler = handler;
    observeQueue = queue;
    observeIntervalTime = time;
}

- (void)removePlayer {
    if (timeObserve) {
        [self.rendererSynchronizer removeTimeObserver:timeObserve];
        timeObserve = nil;
    }

    videoState -> quit = YES;
    [self stopEnqueue];
    pthread_mutex_lock(&videoMutex);
    pthread_mutex_lock(&audioMutex);
    [self.decoderManager destroyDecoderManager];

}

#pragma mark Get Method
- (Float64)getDuration {
    int64_t duration = formatContext -> duration;
    return duration * 1.f / AV_TIME_BASE;
}

- (Float64)getCurrentTime {
    return CMTimeGetSeconds(self.rendererSynchronizer.currentTime);
}

#pragma mark Private Method
- (void)updatePlayer:(CMTime)time queue:(nonnull dispatch_queue_t)queue usingBlock:(void (^)(CMTime time))handler{
    if (timeObserve) {
        [self.rendererSynchronizer removeTimeObserver:timeObserve];
        timeObserve = nil;
    }

    if (queue != nil && handler != nil && CMTimeGetSeconds(time)) {
        timeObserve = [self.rendererSynchronizer addPeriodicTimeObserverForInterval:time queue:queue usingBlock:handler];
    }
}

- (void)restartPlayerAtStartTime:(Float64)timeStamp {
    float rate = self.rendererSynchronizer.rate;
    [self stopEnqueue];
    [self updatePlayer:observeIntervalTime queue:observeQueue usingBlock:self.handler];

    [self.audioRenderer requestMediaDataWhenReadyOnQueue:audioGetBufferQueue usingBlock:^{
        pthread_mutex_lock(&self -> audioMutex);
        while (self.audioRenderer.isReadyForMoreMediaData) {
            MyPacket myPacket;
            if ([self.audioPacketQueue packet_queue_get:&myPacket]) {
                //if finish
                if (myPacket.packet.data == NULL) {
                    continue;;
                }

                //if seek;
                if (myPacket.packet.data == flushPacket.data) {
                    continue;
                }

                [self.decoderManager startDecodeAudioDataWithAVPacket:myPacket];
                break;
            }else {
                av_usleep(10000);
                break;
            }
        }
        pthread_mutex_unlock(&self -> audioMutex);
    }];

    [self.playLayer requestMediaDataWhenReadyOnQueue:videoGetBufferQueue usingBlock:^{
        pthread_mutex_lock(&self -> videoMutex);
        while (self.playLayer.isReadyForMoreMediaData ) {

            MyPacket myPacket;
            if ([self.videoPacketQueue packet_queue_get:&myPacket]) {
                AVPacket packet = myPacket.packet;
                //
                //if seek;
                if (myPacket.packet.data == flushPacket.data) {
                    continue;
                }

                if (packet.data == NULL) {
                    //if last serial nullPkt: continue
                    if (myPacket.serial != rendererSerial) {
                        continue;
                    }
                    //if video finish
                    [self stopEnqueue];
                    self -> isRestartPlay = YES;
                    break;
                }


                [self.decoderManager startDecodeVideo:myPacket];

                break;
            } else {
                //if queue is empty wait 10ms
                av_usleep(10000);
                break;
            }
        }
        pthread_mutex_unlock(&self -> videoMutex);
    }];
    [self.rendererSynchronizer setRate:rate time:CMTimeMake(timeStamp * AV_TIME_BASE, AV_TIME_BASE)];
}

- (void)stopEnqueue {
    self.rendererSynchronizer.rate = 0;
    [self.audioRenderer stopRequestingMediaData];
    [self.audioRenderer flush];

    [self.playLayer stopRequestingMediaData];
    [self.playLayer flush];
    if (timeObserve) {
        [self.rendererSynchronizer removeTimeObserver:timeObserve];
        timeObserve = nil;
    }

}
#pragma mark Enqueue SampleBuffer

-(void)CJDecoderGetVideoSampleBufferCallback:(MySampleBuffer *)sampleBuffer {

     //if the buffer serial is not equal renderSerial, throw it
    if (sampleBuffer -> serial != rendererSerial) {
        return;
    }

    if (CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer -> sampleBuffer)) < videoState -> seekTimeStamp) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer -> sampleBuffer, YES);
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DoNotDisplay, kCFBooleanTrue);
    }

    if (isSeeking && CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer -> sampleBuffer)) >= videoState -> seekTimeStamp) {
        isSeeking = NO;
    }

    [self.playLayer enqueueSampleBuffer:sampleBuffer -> sampleBuffer];
}

- (void)CJDecoderGetAudioSampleBufferCallback:(MySampleBuffer *)sampleBuffer isFirstFrame:(BOOL)isFirstFrame {
    if (sampleBuffer -> serial != rendererSerial) {
        return;
    }

    if (sampleBuffer -> sampleBuffer) {
        [self.audioRenderer enqueueSampleBuffer:sampleBuffer -> sampleBuffer];
    }


}

#pragma mark other

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath  isEqual: @"status"]) {
        if (self.playLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            self.rendererSynchronizer.rate = 0;
            [self.playLayer flush];
//            [self restartPlayerAtStartTime:CMTimeGetSeconds(self.rendererSynchronizer.currentTime)];
        }
    }
}

- (void)setRate:(int)rate {
    self.rendererSynchronizer.rate = rate;
}

-(void)dealloc {
    rendererSerial = 0;
    free(videoState);
    [self.playLayer removeObserver:self forKeyPath:@"status"];
    [self.audioRenderer removeObserver:self forKeyPath:@"status"];
}

@end
