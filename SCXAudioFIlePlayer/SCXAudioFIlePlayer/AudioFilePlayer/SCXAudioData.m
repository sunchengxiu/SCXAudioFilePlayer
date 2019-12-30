//
//  SCXAudioData.m
//  SCXAudioFIlePlayer
//
//  Created by 孙承秀 on 2019/12/30.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "SCXAudioData.h"

@implementation SCXAudioData
+(instancetype)audioDataWithBytes:(const void *)bytes packetDescription:(AudioStreamPacketDescription)aspd{
    return [[self alloc] initWithBytes:bytes aspd:aspd];
}
- (instancetype)initWithBytes:(const void *)bytes aspd:(AudioStreamPacketDescription)aspd{
    if (bytes == NULL || aspd.mDataByteSize == 0) {
        return nil;
    }
    if (self = [super init]) {
        _data = [NSData dataWithBytes:bytes length:aspd.mDataByteSize];
        _aspd = aspd;
    }
    return self;
}
@end
