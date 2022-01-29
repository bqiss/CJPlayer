//
//  XDXVideoDecoder.h
//  XDXVideoDecoder
//
//  Created by 小东邪 on 2019/6/4.
//  Copyright © 2019 小东邪. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFmpegParseHandler.h"
#import <VideoToolbox/VideoToolbox.h>
#import <pthread.h>

NS_ASSUME_NONNULL_BEGIN


@protocol VideoToolBoxDecoderDeltegate <NSObject>

@optional
- (void)getVideoDecodeDataByVideoToolBox:(MySampleBuffer *)samplebuffer;
@end

@interface VideoToolBoxDecoder : NSObject

@property (weak, nonatomic) id<VideoToolBoxDecoderDeltegate> delegate;


/**
    Start / Stop decoder
 */
- (void)startDecodeVideoData:(struct ParseVideoDataInfo *)videoInfo;
- (void)stopDecoder;
- (void)resetIsFirstFrame;

@end

NS_ASSUME_NONNULL_END
