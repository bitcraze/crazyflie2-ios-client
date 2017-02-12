//
//  DataStruct.m
//  Crazyflie client
//
//  Created by Martin Eberl on 12.02.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

#import "CommandPacket.h"

@implementation CommandPacketCreator

+ (NSData *)dataFrom:(CommanderPacket) packet {
    NSData *data = [NSData dataWithBytes:&packet length:sizeof(CommanderPacket)];
    //NSLog(@"%@", data);
    //30000000 00000000 80000000 000000 -> Default data package without any input
    return data;
}

@end
