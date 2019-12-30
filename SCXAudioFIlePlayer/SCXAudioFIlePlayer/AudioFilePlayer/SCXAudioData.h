//
//  SCXAudioData.h
//  SCXAudioFIlePlayer
//
//  Created by 孙承秀 on 2019/12/30.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
NS_ASSUME_NONNULL_BEGIN

@interface SCXAudioData : NSObject

/**
 data
 */
@property(nonatomic , strong , readonly)NSData *data;

/**
 aspd
 */
@property(nonatomic , assign , readonly)AudioStreamPacketDescription aspd;

+ (instancetype)audioDataWithBytes:(const void *)bytes packetDescription:(AudioStreamPacketDescription)aspd;

@end

NS_ASSUME_NONNULL_END
