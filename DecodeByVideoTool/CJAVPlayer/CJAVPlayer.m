//
//  CJAVPlayerItem.m
//  DecodeByVideoTool
//
//  Created by 陈剑 on 2022/1/7.
//

#import "CJAVPlayer.h"


static int rendererSerial = 0;

@interface CJAVPlayer()<CJDecoderManagerCallDelegate>
{
    AVFormatContext * formatContext;
    dispatch_queue_t queue;
    BOOL isSeeking;
    BOOL isRunning;
    BOOL isDecoding;
    BOOL timeBaseIsReset;
    VideoState *videoState;
}


@property (nonatomic, strong) CJDecoderManager * decoderManager;

@property (nonatomic, strong) AVSampleBufferRenderSynchronizer * rendererSynchronizer;

@property (nonatomic, strong) AVSampleBufferAudioRenderer * audioRenderer;

@end

@implementation CJAVPlayer
- (instancetype)initWithURL:(NSURL *)url layerFrame:(CGRect)frame fileType: (fileType)fileType {
    if (self = [super init]) {
        queue = dispatch_queue_create("playerQueue", DISPATCH_QUEUE_SERIAL);
        [self initLayerAndAudioRenderer:frame];
        [self preparePlayer:url fileType:fileType];
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
}

- (void)preparePlayer:(NSURL *)url fileType:(fileType) fileType {

    videoState = malloc(sizeof(VideoState));
    self.decoderManager = [[CJDecoderManager alloc]initWithFilePath:url.relativePath fileType:fileType videoState:videoState];
    self.decoderManager.delegate = self;
    formatContext = [self.decoderManager getFormatContext];

    self.rendererSynchronizer = [[AVSampleBufferRenderSynchronizer alloc]init];
    [self.rendererSynchronizer addRenderer:self.playLayer];
    [self.rendererSynchronizer addRenderer:self.audioRenderer];
    [self.rendererSynchronizer setRate:1];


}

#pragma  mark Public Method

- (void)pause {
    self.rendererSynchronizer.rate = 0;
}

- (void)play {
    if (!isRunning) {
        [self restartPlayerAtStartTime:0];
        [self.decoderManager startDecode:videoState];
        self.rendererSynchronizer.rate = 1;
        isRunning = YES;
    }else {
        float rate = self.rendererSynchronizer.rate;
        if (rate != 0) {
            return;
        }
        self.rendererSynchronizer.rate = 1;
    }

}

- (void)seekToTime:(Float64)timeStamp {

    [self restartPlayerAtStartTime:timeStamp];
    videoState -> isSeekReq = YES;
}

- (void)addPeriodicTimeObserverForInterval:(CMTime)time queue:(nonnull dispatch_queue_t)queue usingBlock:(void (^)(CMTime time))handler{
//    [self.videoRenderSynchronizer addPeriodicTimeObserverForInterval:time queue:queue usingBlock:handler];
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

- (void)restartPlayerAtStartTime:(Float64)timeStamp {
    float rate = self.rendererSynchronizer.rate;
    [self stopEnqueue];
    rendererSerial++;
    videoState -> seekTimeStamp = timeStamp;
    [self.rendererSynchronizer setRate:rate time:CMTimeMake(timeStamp * AV_TIME_BASE, AV_TIME_BASE)];
    NSLog(@"timebaseReset:%f",CMTimeGetSeconds(CMTimebaseGetTime(self.rendererSynchronizer.timebase)));
}
- (void)stopEnqueue {

    self.rendererSynchronizer.rate = 0;
    NSLog(@"rateIsSetZero!");
    [self.audioRenderer stopRequestingMediaData];
    [self.audioRenderer flush];

    [self.playLayer stopRequestingMediaData];
    [self.playLayer flush];
}
#pragma mark Enqueue SampleBuffer

-(void)CJDecoderGetVideoSampleBufferCallback:(MySampleBuffer *)sampleBuffer {
    //    if (sampleBuffer -> serial == rendererSerial) {
    //        isSeeking = NO;
    //    }
    //
    //    if (sampleBuffer -> serial != rendererSerial || isSeeking) {
    //        NSLog(@"throwBuffer:%f",CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer -> sampleBuffer)));
    //        return;
    //    }
    //
    //    if (CMTimeGetSeconds(CMTimebaseGetTime(self.rendererSynchronizer.timebase)) > CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer -> sampleBuffer))) {
    //        NSLog(@"throwBuffer synchronizer:%f",CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer -> sampleBuffer)));
    //        return;
    //    }

//    Float64 pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer -> sampleBuffer));
//    Float64 timebase = CMTimeGetSeconds(CMTimebaseGetTime(self.rendererSynchronizer.timebase));
//    if (pts < timebase && timebase - pts > 3) {
//        [self pause];
//    } else {
//        self.rendererSynchronizer.rate = 1;
//    }

    [self.playLayer enqueueSampleBuffer:sampleBuffer -> sampleBuffer];

    NSLog(@"videoEnqueue:%f，timebase:%f",CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer -> sampleBuffer)),CMTimeGetSeconds(CMTimebaseGetTime(self.rendererSynchronizer.timebase)));
}

- (void)CJDecoderGetAudioSampleBufferCallback:(MySampleBuffer *)sampleBuffer isFirstFrame:(BOOL)isFirstFrame {

//    if (sampleBuffer -> serial == rendererSerial) {
//        isSeeking = NO;
//    }
//
//    if (sampleBuffer -> serial != rendererSerial || isSeeking) {
//        NSLog(@"throwBuffer:%f",CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer -> sampleBuffer)));
//        return;
//    }

//    if (CMTimeGetSeconds(CMTimebaseGetTime(self.rendererSynchronizer.timebase)) > CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer -> sampleBuffer))) {
//        return;
//    }


    [self.audioRenderer enqueueSampleBuffer:sampleBuffer -> sampleBuffer];
    NSLog(@"audioEnqueue:%f，timebase:%f",CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer -> sampleBuffer)),CMTimeGetSeconds(CMTimebaseGetTime(self.rendererSynchronizer.timebase)));
}


@end
