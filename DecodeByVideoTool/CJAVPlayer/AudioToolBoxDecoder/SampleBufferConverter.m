//
//  SampleBufferConverter.m
//  DecodeByVideoTool
//
//  Created by 陈剑 on 2022/1/4.
//

#import "SampleBufferConverter.h"
@interface SampleBufferConverter ()
{
    Float64 startOffset;
}
@end
@implementation SampleBufferConverter
- (instancetype)init {
    if (self = [super init]) {
        startOffset = 0;
    }
    return self;
}

//AudioBufferList * _Nonnull destBufferList, UInt32 outputPackets, AudioStreamPacketDescription * _Nonnull outputPacketDescriptions

- (CMSampleBufferRef)converSampleBufferFrom:(AudioBufferList *)destBufferList outputBasicDescriptions:(AudioStreamBasicDescription *)outputBasicDescriptions frameCapacity:(AVAudioFrameCount)frameCapacity pts:(Float64)pts{

    AVAudioChannelLayout *chLayout = [[AVAudioChannelLayout alloc] initWithLayoutTag:kAudioChannelLayoutTag_Stereo];
    AVAudioFormat *chFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                              sampleRate:48000
                                                              interleaved:NO
                                                            channelLayout:chLayout];
    AVAudioPCMBuffer *pcmBuffer = [[AVAudioPCMBuffer alloc]initWithPCMFormat:chFormat frameCapacity:frameCapacity];
    CMBlockBufferRef blockBuffer = [self makeBlockFrom:destBufferList];

    CMSampleBufferRef sampleBuffer = NULL;
    CMTime prenstationTimeStamp = CMTimeMake(pts * outputBasicDescriptions -> mSampleRate, outputBasicDescriptions -> mSampleRate);
    OSStatus status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(kCFAllocatorDefault, blockBuffer, pcmBuffer.format.formatDescription, 1, prenstationTimeStamp, nil, &sampleBuffer);

    if (status != noErr) {
        NSLog(@"CMAudioSampleBufferCreateReadyWithPacketDescriptions fail!");
        return NULL;
    }
    return sampleBuffer;
}

- (CMBlockBufferRef)makeBlockFrom: (AudioBufferList *)destBufferList {
    OSStatus status;
    CMBlockBufferRef outBlockListBuffer = NULL;
    status = CMBlockBufferCreateEmpty(kCFAllocatorDefault, 0, 0, &outBlockListBuffer);

    if (status != noErr) {
        NSLog(@"CMBlockBufferCreateEmpty fail!");
        return NULL;
    }

    CMBlockBufferRef blockListBuffer = outBlockListBuffer;

    for (int i = 0;i < destBufferList -> mNumberBuffers; i++) {
        CMBlockBufferRef outBlockBuffer = NULL;
        int dataByteSize = destBufferList -> mBuffers[i].mDataByteSize;

        status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, nil, dataByteSize, kCFAllocatorDefault, nil, 0, dataByteSize, kCMBlockBufferAssureMemoryNowFlag, &outBlockBuffer);

        if (status != noErr) {
            NSLog(@"CMBlockBufferCreateWithMemoryBlock fail!");
            return NULL;
        }

        CMBlockBufferRef blockBuffer = outBlockBuffer;

        status = CMBlockBufferReplaceDataBytes(destBufferList -> mBuffers[i].mData, blockBuffer, 0, dataByteSize);

        if (status != noErr) {
            NSLog(@"CMBlockBufferReplaceDataBytes fail!");
            return NULL;
        }

        status = CMBlockBufferAppendBufferReference(blockListBuffer, blockBuffer, 0, CMBlockBufferGetDataLength(blockBuffer), 0);

        if (status != noErr) {
            NSLog(@"CMBlockBufferAppendBufferReference fail!");
            return NULL;
        }
    }
    return blockListBuffer;
}
@end
