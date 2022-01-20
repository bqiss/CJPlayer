//
//  SampleBufferConverter.h
//  DecodeByVideoTool
//
//  Created by 陈剑 on 2022/1/4.
//

#import <Foundation/Foundation.h>
#import "CJDecoderManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface SampleBufferConverter : NSObject
- (CMSampleBufferRef)converSampleBufferFrom:(AudioBufferList *)destBufferList outputBasicDescriptions:(AudioStreamBasicDescription *)outputBasicDescriptions frameCapacity:(AVAudioFrameCount)frameCapacity pts:(Float64)pts;
@end

NS_ASSUME_NONNULL_END
