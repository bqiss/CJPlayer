//
//  CJAudioDecoder.h
//  DecodeByVideoToolBox
//
//  Created by 陈剑 on 2021/12/27.
//

#import <Foundation/Foundation.h>
#import "AVFoundation/AVFoundation.h"
#import "FFmpegParseHandler.h"
#import <pthread.h>

NS_ASSUME_NONNULL_BEGIN
struct AudioDescription {
    AudioStreamBasicDescription asbd;
    int frameSize;
    int out_linesize;
    int out_buffer_size;
};

struct AudioData {
    uint8_t * data;
    int size;
    int serial;
    Float64 pts;
    Float64 duration;
};

@protocol CJAudioDecoderDelegate <NSObject>
@optional
- (void)getAudioDecodeDataByFFmpeg:(struct AudioData *)audioData serial:(int)serial isFirstFrame:(BOOL)isFirstFrame;

@end
@interface CJAudioDecoder : NSObject

@property (nonatomic, weak) id<CJAudioDecoderDelegate> delegate;

- (instancetype)initWithFormatContext:(AVFormatContext *)formatContext audioStreamIndex:(int)audioStreamIndex;

- (void)startDecodeAudioDataWithAVPacket:(MyPacket)packet;

- (void)stopDecoder;

- (void)resetIsFirstFrame;

- (struct AudioDescription)getAudioDesc;
@end

NS_ASSUME_NONNULL_END
