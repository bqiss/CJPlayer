//
//  CJAVPlayer.h
//  DecodeByVideoTool
//
//  Created by 陈剑 on 2022/1/7.
//

#import <Foundation/Foundation.h>
#import "CJDecoderManager.h"
#import "CJAVPlaylayer.h"
NS_ASSUME_NONNULL_BEGIN

@interface CJAVPlayer : NSObject
@property (nonatomic, strong) CJAVPlaylayer * playLayer;

@property (nonatomic, assign) int palyerRate;

- (instancetype)initWithURL:(NSURL *)url layerFrame:(CGRect)frame;

- (void)play;

- (void)pause;

- (void)seekToTime: (Float64)timeStamp;

- (void)addPeriodicTimeObserverForInterval:(CMTime)time queue:(nonnull dispatch_queue_t)queue usingBlock:(void (^)(CMTime time))handler;

- (Float64)getDuration;

- (Float64)getCurrentTime;
@end

NS_ASSUME_NONNULL_END
