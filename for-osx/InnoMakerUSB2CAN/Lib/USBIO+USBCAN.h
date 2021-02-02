//
//  USBIO.h
//  InnoMakerUSB2CAN
//
//  Created by Inno-Maker on 2020/4/5.
//  Copyright © 2020 Inno-Maker. All rights reserved.
//

/**********************************************************************
Class : UsbIO
Author : Inno-Maker
Date: 04.21.2020
Version : 1.0
Routines to Proivde InnoMaker Client Device Applicate Interface
***********************************************************************/

#import "UsbIO.h"

struct innomaker_host_frame {
    uint32_t echo_id;
    uint32_t can_id;
    uint8_t can_dlc;
    uint8_t channel;
    uint8_t flags;
    uint8_t reserved;
    uint8_t data[8];
};

struct innomaker_device_mode {
    uint32 mode;
    uint32 flags;
};

struct innomaker_device_bittiming {
    uint32 prop_seg;
    uint32 phase_seg1;
    uint32 phase_seg2;
    uint32 sjw;
    uint32 brp;
};

struct innomaker_identify_mode {
    uint32 mode;
};

struct innomaker_device_bt_const {
    uint32 feature;
    uint32 fclk_can;
    uint32 tseg1_min;
    uint32 tseg1_max;
    uint32 tseg2_min;
    uint32 tseg2_max;
    uint32 sjw_max;
    uint32 brp_min;
    uint32 brp_max;
    uint32 brp_inc;
} ;

typedef enum : NSUInteger {
    UsbCanModeNormal,
    UsbCanModeLoopback,
    UsbCanModeListenOnly,
}UsbCanMode;

@interface UsbIO (USBCan)

/*!
 Urb Clear PipeOut Stall
 @param device target device
 */
- (BOOL)UrbClearPipeOutStall:(InnoMakerDevice *)device;

/*!
 Urb Clear PipeIn Stall
 @param device target device
 */
- (BOOL)UrbClearPipeInStall:(InnoMakerDevice *)device;

/*!
 Urb reset device
 @param device target device
 */
- (BOOL)UrbResetDevice:(InnoMakerDevice *)device;

/*!
 Urb setup device
 @param dev target device
 @param mode dev mode
 @param bittiming bittiming
 */
- (BOOL)UrbSetupDevice:(InnoMakerDevice *)dev
                  mode:(UsbCanMode) mode
              bittiming:(struct innomaker_device_bittiming)bittiming;
@end


