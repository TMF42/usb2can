//
//  ViewController.m
//  InnoMakerUSB2CAN
//
//  Created by Inno-Maker on 2020/4/3.
//  Copyright © 2020 Inno-Maker. All rights reserved.
//

#import "ViewController.h"
#import "UsbIO.h"
#import "USBIO+USBCAN.h"
#import "FrameViewModel.h"
#import "NSData+HexPresention.h"
#import "DAConfig.h"
#import "NSBundle+DAUtils.h"

#define GS_MAX_TX_URBS 10

struct gs_tx_context {
    unsigned int echo_id;
};

struct gs_can {
    /* This lock prevents a race condition between xmit and receive. */
    OSSpinLock tx_ctx_lock;
    struct gs_tx_context tx_context[GS_MAX_TX_URBS];
};


typedef enum _FrameFormat {
    FrameFormatStandard = 0
} FrameFormat;

/// Frame Type
typedef enum _FrameType {
    FrameTypeData = 0
} FrameType;

/// Can Mode
typedef enum _CanMode{
    CanModeNormal = 0
}CanMode;

/// Bitrate
typedef enum _Bitrate{
    BitrateTenMillionsBit = 0
}Bitrate ;

/// Check ID
typedef enum _CheckIDType{
    CheckIDTypeNone = 0,
    CheckIDTypeIncrease = 1
}CheckIDType;

/// Check data
typedef enum _CheckDataType {
    CheckDataTypeNone = 0,
    CheckDataTypeIncrease = 1
}CheckDataType;

/// ErrorFrame flag
typedef enum _CheckErrorFrame {
    _CheckErrorFrameClose = 0,
    _CheckErrorFrameOpen = 1
}CheckErrorFrame;

/// System language
typedef enum _SystemLanguage {
    DefaultLanguage = 0,
    EnglishLanguage = 1,
    ChineseLanguage = 2
}SystemLanguage;

@interface ViewController()<InnoMakerDeviceDelegate,
NSTextFieldDelegate,
NSTableViewDataSource,
NSTableViewDelegate,
NSComboBoxDataSource,
NSComboBoxDelegate>
@property (nonatomic,assign) FrameFormat frameFormat;
@property (nonatomic,assign) FrameType frameType;
@property (nonatomic,assign) CanMode canMode;
@property (nonatomic,assign) Bitrate bitrate;
@property (nonatomic,assign) CheckIDType checkIdType;
@property (nonatomic,assign) CheckDataType checkDataType;
@property (nonatomic,assign) CheckErrorFrame checkErrorFrame;
@property (nonatomic,strong) UsbIO *usbIO;
@property (nonatomic,strong) NSMutableArray *devIndexes;
@property (nonatomic,strong) NSMutableArray *bitrateIndexes;
@property (nonatomic,strong) NSMutableArray <FrameViewModel *>*recvFrame;
@property (nonatomic,assign) SystemLanguage currentLanguage;
/// Recv timer
@property (nonatomic,strong) NSTimer *recvTimer;
/// Send timer
@property (nonatomic,strong) dispatch_source_t sendTimer;
/// Current device
@property (nonatomic,strong) InnoMakerDevice *currentDevice;
/// Current select bitrate
@property (nonatomic,assign) int curBitrateSelectIndex;
/// Current work mode
@property (nonatomic,assign) int curWorkModeSelectIndex;
/// Current device
@property (nonatomic,assign) struct gs_can can;
/// Recv thread
@property (nonatomic,strong) NSThread *recvThread;
/// Send thread
@property (nonatomic,strong) NSThread *sendThread;
@end

@implementation ViewController

#pragma mark - life cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    _logoInfo.stringValue = @"www.inno-maker.com  wiki.inno-maker.com  sales@inno-maker.com  support@inno-maker.com";
    
    /// Default standard frame format
    _frameFormat = FrameFormatStandard;
    /// Default data frame type
    _frameType = FrameTypeData;
    /// Default normal mode
    _canMode = CanModeNormal;
    /// Default 10MBits
    _bitrate = BitrateTenMillionsBit;
    /// Default check id none
    _checkIdType = CheckIDTypeNone;
    /// Default check data none
    _checkDataType = CheckDataTypeNone;
    /// Default check error close
    _checkErrorFrame = _CheckErrorFrameClose;
    
    /// Default one frame
    _totalFrameTextField.stringValue = @"1";
    /// Default one second
    _periodTextField.stringValue = @"1000";
    _recvFrame = [NSMutableArray array];
    _curBitrateSelectIndex = -1;
    _curWorkModeSelectIndex = -1;
    
    /// Init USBIO Instance
    _usbIO = [[UsbIO alloc]init];
    [_usbIO setDelegate:self];
    [_usbIO setInnoMakerDeviceInfo:0x606f andVid:0x1d50];
    
    /// Default frame id ,frame data
    _frameIdTextField.stringValue = @"00 00 00 00";
    _frameDataTextField.stringValue = @"00 00 00 00 00 00 00 00";
    
    /// Init Dev Indexes
    _devIndexes = [[NSMutableArray alloc]init];
    _bitrateIndexes = [NSMutableArray arrayWithObjects:
                       @"20K",
                       @"33.33K",
                       @"40K",
                       @"50K",
                       @"66.66K",
                       @"80K",
                       @"83.33K",
                       @"100K",
                       @"125K",
                       @"200K",
                       @"250K",
                       @"400K",
                       @"500K",
                       @"666K",
                       @"800K",
                       @"1000K",
                       nil];
    
    
    _bitrateComboBox.stringValue = @"";
    _bitrateComboBox.editable = false;
    _workModeComboBox.stringValue = @"";
    _workModeComboBox.editable = false;
    _devComboBox.stringValue = @"";
    _devComboBox.editable = false;
    _langComboBox.editable = false;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    
    _openDeviceBtn.title = NSLocalizedStringFromTable(@"open-device", @"Main", @"open-device");
    _openDeviceBtn.tag = 0;
    _mutleSendBtn.tag = 0;
    /// Read local language
    if ([DAConfig userLanguage] == nil) {
        _currentLanguage = DefaultLanguage;
        _langComboBox.stringValue = @"English";
        _langTextField.stringValue = @"Language";
    } else if([[DAConfig userLanguage] isEqualToString:@"zh-Hans"]) {
        _currentLanguage = ChineseLanguage;
        _langComboBox.stringValue = @"Chinese";
        _langTextField.stringValue = @"语言";
    } else if([[DAConfig userLanguage] isEqualToString:@"en"]){
        _currentLanguage = EnglishLanguage;
        _langComboBox.stringValue = @"English";
        _langTextField.stringValue = @"Language";
    }
    
    
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}


#pragma mark - datasource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    if (aComboBox == _devComboBox) {
        return [_devIndexes count];
    }
    if (aComboBox == _bitrateComboBox) {
        return [_bitrateIndexes count];
    }
    return 0;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    if (aComboBox == _devComboBox) {
        return [_devIndexes objectAtIndex:index];
    }
    if (aComboBox == _bitrateComboBox) {
        return [_bitrateIndexes objectAtIndex:index];
    }
    return @"";
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSComboBox *comboBox = (NSComboBox *)notification.object;
    if (comboBox == _langComboBox) {
        if (comboBox.indexOfSelectedItem == 0) {
            [self chanageCurrentLanguage:EnglishLanguage];
        } else {
            [self chanageCurrentLanguage:ChineseLanguage];
        }
    }
    if (comboBox == _devComboBox) {
        _currentDevice = [_usbIO getInnoMakerDevice:[comboBox indexOfSelectedItem]];
        if (_currentDevice == nil) {
            NSLog(@"Device is null!");
        }
    }
    if (comboBox == _bitrateComboBox) {
        _curBitrateSelectIndex =  (int)[comboBox indexOfSelectedItem];
    }
    if (comboBox == _workModeComboBox) {
        _curWorkModeSelectIndex = (int)[comboBox indexOfSelectedItem];
    }
}
#pragma mark - delegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _recvFrame.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    FrameViewModel *model = [_recvFrame objectAtIndex:row];
    NSTableCellView *cellView = [self configColumnWithTable:tableView model:model column:tableColumn];
    return cellView;
}

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
    
}

- (void)controlTextDidChange:(NSNotification *)obj {
    
    if (obj.object == _frameIdTextField) {
        /// Limit Four Byte
        [self adjustTextFieldToHex:obj.object limitLength:8 needSpacePadding:true];
    }
    else if (obj.object == _frameDataTextField) {
        /// Limite Eight Bytes
        [self adjustTextFieldToHex:obj.object limitLength:16 needSpacePadding:true];
    }
    else if (obj.object == _totalFrameTextField) {
        [self adjustTextFieldToNumber:obj.object minValue:1 maxValue:10000];
    }
    else if (obj.object == _periodTextField) {
        [self adjustTextFieldToNumber:obj.object minValue:1 maxValue:5000];
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if (obj.object == _totalFrameTextField) {
        [self adjustTextFieldToNumber:obj.object minValue:1 maxValue:10000];
        
    }
    else if (obj.object == _periodTextField) {
        [self adjustTextFieldToNumber:obj.object minValue:100 maxValue:5000];
    }
}


/*
 Add device notify
 */
- (void)addDeviceNotify:(InnoMakerDevice*)device {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateDevs];
    });
}

/*
 Remove device notify
 */
- (void)removeDeviceNotify:(InnoMakerDevice*)device {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateDevs];
        
        if (self.currentDevice == nil ||  self.currentDevice == device) {
            self.devComboBox.stringValue = @"";
            self.bitrateComboBox.stringValue = @"";
            self.curBitrateSelectIndex = -1;
            self.currentDevice = nil;
            [self cancelSendTimer];
            [self cancelRecvTimer];
            [self _closeDevice];
            
        }
    });
}

- (void)readDeviceDataNotify:(InnoMakerDevice *)device
                        data:(Byte *)dataByte
                      length:(NSUInteger)length {
    
    /// The length must equal to gs_host_frame format, it is the frame to send and recv
    if (length != sizeof(struct innomaker_host_frame)) {
        return;
    }
    
    Byte echodIdByte[4];
    echodIdByte[0] = dataByte[0];
    echodIdByte[1] = dataByte[1];
    echodIdByte[2] = dataByte[2];
    echodIdByte[3] = dataByte[3];
    
    uint32_t echoId = 0;
    memcpy(&echoId, echodIdByte, 4);
    
    if (echoId == 0xFFFFFFFF) {
        /// @TODO Error frame logic
        NSData *data = [NSData dataWithBytes:dataByte length:length];
        NSLog(@"%s,data=%@",__func__,data);
        FrameViewModel *model = [self dataToModel:data direction:true];
        /// Data Invalid & Check Error Open, Append row
        if (model.isDataValid) {
            [_recvFrame addObject:model];
        }
        else if (!model.isDataValid && _checkErrorFrame == _CheckErrorFrameClose) {
            [_recvFrame addObject:model];
        }
        __weak typeof(self)weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self)strongSelf = weakSelf;
            [strongSelf.tableView reloadData];
            if ([strongSelf isScrollToBottom] ) {
                [strongSelf.tableView scrollRowToVisible:strongSelf.recvFrame.count - 1];
            }
        });
        
    } else {
        NSData *data = [NSData dataWithBytes:dataByte length:length];
        NSLog(@"%s,data=%@",__func__,data);
        Byte echodIdByte[4];
        echodIdByte[0] = dataByte[0];
        echodIdByte[1] = dataByte[1];
        echodIdByte[2] = dataByte[2];
        echodIdByte[3] = dataByte[3];
        uint32_t echoId = 0;
        memcpy(&echoId, echodIdByte, 4);
        struct gs_tx_context *txc = gs_get_tx_context(&self->_can, echoId);
        ///bad devices send bad echo_ids.
        if (!txc) {
            NSLog(@"Unexpected unused echo id %d\n",echoId);
            return;
        }
        gs_free_tx_context(txc);
    }
}

- (void)writeDeviceDataNotify:(InnoMakerDevice *)device
                         data:(Byte *)dataByte
                       length:(NSUInteger)length {
    
    /// The length must equal to gs_host_frame format, it is the frame to send and recv
    if (length != sizeof(struct innomaker_host_frame)) {
        return;
    }
    
    NSData *data = [NSData dataWithBytes:dataByte length:length];
    FrameViewModel *model = [self dataToModel:data direction:false];
    [_recvFrame addObject:model];
    
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self)strongSelf = weakSelf;
        [strongSelf.tableView reloadData];
        
        if ([self isScrollToBottom] ) {
            [strongSelf.tableView scrollRowToVisible:strongSelf.recvFrame.count - 1];
        }
    });
    
}


#pragma mark - user events

- (IBAction)controlSetFrameFormat:(id)sender {
    NSComboBox *comboBox = (NSComboBox *)sender;
    switch (comboBox.selectedTag) {
        case 0:
            break;
        default:
            break;
    }
}


- (IBAction)controlSetFrameType:(id)sender {
    NSComboBox *comboBox = (NSComboBox *)sender;
    switch (comboBox.selectedTag) {
        case 0:
            break;
        default:
            break;
    }
}


- (IBAction)controlSetWorkMode:(id)sender {
    NSComboBox *comboBox = (NSComboBox *)sender;
    switch (comboBox.selectedTag) {
        case 0:
            break;
        default:
            break;
    }
}

- (IBAction)controlCheckId:(id)sender {
    NSButton *button = (NSButton *)sender;
    if (button.state == NSControlStateValueOn) {
        _checkIdType = CheckIDTypeIncrease;
    }
    else {
        _checkIdType = CheckIDTypeNone;
    }
}

- (IBAction)controlCheckData:(id)sender {
    NSButton *button = (NSButton *)sender;
    if (button.state == NSControlStateValueOn) {
        _checkDataType = CheckDataTypeIncrease;
    }
    else {
        _checkDataType = CheckDataTypeNone;
    }
}

- (IBAction)controlErrorFrame:(id)sender  {
    NSButton *button = (NSButton *)sender;
    if (button.state == NSControlStateValueOn) {
        _checkErrorFrame = _CheckErrorFrameOpen;
    }
    else {
        _checkErrorFrame = _CheckErrorFrameClose;
    }
}

- (IBAction)controlSend:(id)sender {
    
    /// If sending,Stop Send Message
    if (_mutleSendBtn.tag == 1) {
        [self cancelSendTimer];
        self.mutleSendBtn.tag = 0;
        self.mutleSendBtn.title = NSLocalizedStringFromTable(@"lzK-xu-4Vr.title",@"Main", @"Delayed Send");
        return;
    }
    /// Start Send message
    /// Get Frame Id
    NSString *frameId = _frameIdTextField.stringValue;
    /// Get Frame Data
    NSString *frameData = _frameDataTextField.stringValue;
    /// Get Total Frame
    int totalFrame = _totalFrameTextField.intValue;
    /// Get Period Time (ms)
    int periodTime = _periodTextField.intValue;
    /// Cancel Timer
    [self cancelSendTimer];
    
    /// Check if device selected
    if (_currentDevice == nil || _currentDevice.isOpen == false) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"device-not-open", @"Main", @"device-not-open")];
        return;
    }
    /// Check if set bitrate
    if (_curBitrateSelectIndex == -1) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"baudrate-not-right", @"Main", @"baudrate-not-right")];
        return;
    }
    
    /// Check if set bitrate
    if (_curWorkModeSelectIndex == -1) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"workmode-not-right", @"Main", @"workmode-not-right")];
        return;
    }
    
    /// Invalid frame id
    if (frameId.length == 0)  {
        [self alertWithMsg:NSLocalizedStringFromTable(@"frameid-not-right", @"Main", @"frameid-not-right")];
        return;
    }
    /// Invalid frame data
    if (frameData.length == 0) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"framedata-not-right", @"Main", @"framedata-not-right")];
        return;
    }
    /// Frame Range
    if (totalFrame < 1 || totalFrame > 100) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"framerange-not-right", @"Main", @"framerange-not-right")];
        return;
    }
    /// Time Range
    if (periodTime < 100 || periodTime > 5000) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"timerange-not-right", @"Main", @"timerange-not-right")];
        return;
    }
    /// Start Send
    _mutleSendBtn.tag = 1;
    _mutleSendBtn.stringValue = NSLocalizedStringFromTable(@"stop-send", @"Main", @"stop-send");
    
    [self setupSendTimer:periodTime frameId:frameId frameData:frameData totalFrame:totalFrame];
}

- (IBAction)controlSingleSend:(id)sender {
    
    /// Get Frame Id
    NSString *frameId = _frameIdTextField.stringValue;
    /// Get Frame Data
    NSString *frameData = _frameDataTextField.stringValue;
    
    /// Check if device selected
    if (_currentDevice == nil ||  _currentDevice.isOpen == false) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"device-not-open", @"Main", @"device-not-open")];
        return;
    }
    /// Check if set bitrate
    
    if (_curBitrateSelectIndex == -1) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"baudrate-not-right", @"Main", @"baudrate-not-right")];
        return;
    }
    
    /// Check if set bitrate
    if (_curWorkModeSelectIndex == -1) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"workmode-not-right", @"Main", @"workmode-not-right")];
        return;
    }
    
    /// Invalid frame id
    if (frameId.length == 0)  {
        [self alertWithMsg:NSLocalizedStringFromTable(@"frameid-not-right", @"Main", @"frameid-not-right")];
        return;
    }
    /// Invalid frame data
    if (frameData.length == 0) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"framedata-not-right", @"Main", @"framedata-not-right")];
        return;
    }
    /* find an empty context to keep track of transmission */
    struct gs_tx_context *txc = gs_alloc_tx_context(&self->_can);
    if (!txc) {
        NSLog(@"NETDEV_TX_BUSY");
        [self alertWithMsg:@"发送繁忙 ERROR:[NETDEV_TX_BUSY]"];
        return;
    }
    /// Build Standard Frame
    NSData *standardFrameData = [self buildStandardFrame:frameId
                                               frameData:frameData
                                                  echoId:txc->echo_id];
    __weak typeof(self)strongSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [strongSelf.usbIO sendInnoMakerDeviceBuf:strongSelf.currentDevice andBuffer:(Byte*)standardFrameData.bytes andSize:(int)standardFrameData.length];
    });
    
    
}

- (IBAction)clear:(id)sender {
    [_recvFrame removeAllObjects];
    [_tableView reloadData];
}

- (IBAction)scanDevices:(id)sender {
    _currentDevice = nil;
    _devComboBox.stringValue = @"";
    [_usbIO scanInnoMakerDevices];
    [self updateDevs];
}

- (IBAction)changeLanguage:(id)sender {
    if (_currentLanguage == ChineseLanguage) {
        [self chanageCurrentLanguage:EnglishLanguage];
    } else {
        [self chanageCurrentLanguage:ChineseLanguage];
    }
}

- (IBAction)exportFile:(id)sender {
    [self exportLogFile];
}

- (IBAction)openDevice:(id)sender {
    /// Open Device
    if (_openDeviceBtn.tag == 0) {
        [self _openDevice];
    }
    /// Close Device
    else {
        
        [self _closeDevice];
        
    }
}

- (IBAction)changeToChinese:(id)sender {
    [self chanageCurrentLanguage:ChineseLanguage];
}

- (IBAction)changeToEnglish:(id)sender {
    [self chanageCurrentLanguage:EnglishLanguage];
}
#pragma mark - functions
/*
  Update devices
 */
- (void)updateDevs {
    UInt8 devCount = [_usbIO getInnoMakerDeviceCount];
    // Remove devices
    [_devIndexes removeAllObjects];
    // Fill devices
    InnoMakerDevice *device;
    NSString *devStr;
    
    for(int i = 0; i < devCount ;i++) {
        device = [_usbIO getInnoMakerDevice:i];
        devStr = [NSString stringWithFormat:@"device %d, ID:%x",i,[device deviceID]];
        [_devIndexes addObject:devStr];
    }
    [_devComboBox reloadData];
}

/// Read Dev Data
- (void)inputFromDev{
    InnoMakerDevice *currentDevice =  _currentDevice;
    if (_currentDevice == nil || currentDevice.isOpen == false ) {
        [self cancelRecvTimer]; return;
    }
    
    int size = sizeof(struct innomaker_host_frame);
    Byte inputBytes[size];
    UInt32 validSize = size;
    if (kIOReturnSuccess == [_usbIO getInnoMakerDeviceBuf:_currentDevice
                                                andBuffer:inputBytes
                                                  andSize:&validSize]) {
        
    } else {
        
    }
}

/// Change current  language
/// @param language language
- (void)chanageCurrentLanguage:(SystemLanguage)language {
    _currentLanguage = language;
    switch (_currentLanguage) {
        case DefaultLanguage:
            [DAConfig resetSystemLanguage];
            break;
        case EnglishLanguage:
            [DAConfig setUserLanguage:@"en"];
            break;
        case ChineseLanguage:
            [DAConfig setUserLanguage:@"zh-Hans"];
            break;;
        default:
            break;
    }
    
    /// Close curren device
    if (_currentDevice.isOpen) {
        [_usbIO closeInnoMakerDevice:_currentDevice];
        _currentDevice = nil;
    }
    /// Cancel recv timer
    [self cancelRecvTimer];
    /// Cancel send timer
    [self cancelSendTimer];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSViewController *mainViewController = [[NSStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateControllerWithIdentifier:@"MainViewController"];
        [NSApplication sharedApplication].keyWindow.contentViewController =  mainViewController;
    });
}

- (void)_openDevice {
    /// Check if device selected
    if (_currentDevice == nil ) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"device-not-open", @"Main", @"device-not-open")];
        return;
    }
    
    /// Check if set bitrate
    if (_curWorkModeSelectIndex == -1) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"workmode-not-right", @"Main", @"workmode-not-right")];
        return;
    }
    
    /// Check if set bitrate
    if (_curBitrateSelectIndex == -1) {
        [self alertWithMsg:NSLocalizedStringFromTable(@"baudrate-not-right", @"Main", @"baudrate-not-right")];
        return;
    }
    
    [_usbIO openInnoMakerDevice:_currentDevice];
    UsbCanMode usbCanMode = UsbCanModeNormal;
    if (_curWorkModeSelectIndex == 0) {
        usbCanMode = UsbCanModeNormal;
    } else if (_curWorkModeSelectIndex == 1) {
        usbCanMode = UsbCanModeLoopback ;
    } else if (_curWorkModeSelectIndex == 2) {
        usbCanMode = UsbCanModeListenOnly;
    }
 
    [_usbIO UrbSetupDevice:_currentDevice
                      mode:usbCanMode
                 bittiming:[self getBittiming:_curBitrateSelectIndex]];
    
    /// Reset current device tx_context
    for (int i = 0; i < GS_MAX_TX_URBS; i++) {
        _can.tx_context[i].echo_id = GS_MAX_TX_URBS;
    }
    [self setupRecvTimer];
    _openDeviceBtn.tag = 1;
    _openDeviceBtn.title = NSLocalizedStringFromTable(@"close-device", @"Main", @"close-device");
    _bitrateComboBox.enabled = false;
    _devComboBox.enabled = false;
    _workModeComboBox.enabled = false;
    _scanDeviceBtn.enabled = false;
}


- (void)_closeDevice {
    
    [self cancelSendTimer];
    [self cancelRecvTimer];
    if (_currentDevice && _currentDevice.isOpen) {
        
        /// Reset current device tx_context
        for (int i = 0; i < GS_MAX_TX_URBS; i++) {
            _can.tx_context[i].echo_id = GS_MAX_TX_URBS;
        }
        [_usbIO UrbResetDevice:_currentDevice];
        [_usbIO closeInnoMakerDevice:_currentDevice];
    }
    
    _bitrateComboBox.enabled = true;
    _devComboBox.enabled = true;
    _scanDeviceBtn.enabled = true;
    _workModeComboBox.enabled = true;
    _openDeviceBtn.tag = 0;
    _openDeviceBtn.title = NSLocalizedStringFromTable(@"open-device", @"Main", @"open-device");
    self.mutleSendBtn.tag = 0;
    self.mutleSendBtn.title = NSLocalizedStringFromTable(@"lzK-xu-4Vr.title",@"Main", @"Delayed Send");
}


/// Setup timer, repeat input from dev (300ms)
/// Scan Interval: 30ms
- (void)setupRecvTimer {
    
    [self cancelRecvTimer];
    
    _recvTimer =  [NSTimer timerWithTimeInterval:0.03 target:self selector:@selector(inputFromDev) userInfo:NULL repeats:YES];
    _recvThread = [[NSThread alloc]initWithTarget:self selector:@selector(recvTimerThreadEntryEndpoit:) object:_recvTimer];
    [_recvThread start];
    
}


- (void)recvTimerThreadEntryEndpoit:(NSTimer *)recvTimer {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [[NSThread currentThread] setName:@"USB2CANRecv"];
    [[NSRunLoop currentRunLoop] addTimer:recvTimer forMode:NSDefaultRunLoopMode];
    [runLoop run];
}

- (void)cancelRecvTimer {
    [_recvThread cancel];
    if (_recvTimer) {
        [_recvTimer invalidate];
        _recvTimer = nil;
    }
}

- (void)setupSendTimer:(int)periodTime
               frameId:(NSString *)frameId
             frameData:(NSString *)frameData
            totalFrame:(int)totalFrame{
    
    [self cancelSendTimer];
    
    
    
    /* find an empty context to keep track of transmission */
    struct gs_tx_context *txc = gs_alloc_tx_context(&self->_can);
    if (!txc) {
        NSLog(@"NETDEV_TX_BUSY");
        [self alertWithMsg:@"发送繁忙 ERROR:[NETDEV_TX_BUSY]"];
        return;
    }
    
    /// Reset Timer
    _sendTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    
    dispatch_source_set_timer(_sendTimer, DISPATCH_TIME_NOW, periodTime * NSEC_PER_MSEC,
                              100 * NSEC_PER_SEC);
    
    __weak typeof(self)weakSelf = self;
    /// Timer Repeat Send
    __block int sendFrame = 0;
    
    /// Build Standard Frame
    __block NSData *standardFrameData = [self buildStandardFrame:frameId
                                                       frameData:frameData
                                                          echoId:txc->echo_id];
    __block NSString *_frameId = frameId;
    __block NSString *_frameData = frameData;
    dispatch_source_set_event_handler(_sendTimer, ^{
        __strong typeof(self)strongSelf = weakSelf;
        
        /* find an empty context to keep track of transmission */
        struct gs_tx_context *txc = gs_alloc_tx_context(&self->_can);
        if (!txc) {
            NSLog(@"NETDEV_TX_BUSY");
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf cancelSendTimer];
                self.mutleSendBtn.tag = 0;
                self.mutleSendBtn.title = NSLocalizedStringFromTable(@"lzK-xu-4Vr.title",@"Main", @"Delayed Send");
                [self alertWithMsg:@"发送繁忙 ERROR:[NETDEV_TX_BUSY]"];
            });
            return;
        }
        
        [strongSelf.usbIO sendInnoMakerDeviceBuf: strongSelf.currentDevice andBuffer:(Byte*)standardFrameData.bytes andSize:(int)standardFrameData.length];
        
        
        if (sendFrame + 1 >= totalFrame) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf cancelSendTimer];
                self.mutleSendBtn.tag = 0;
                self.mutleSendBtn.title = NSLocalizedStringFromTable(@"lzK-xu-4Vr.title",@"Main", @"Delayed Send");
            });
            
            return;
        }
        
        if (strongSelf.currentDevice == nil || strongSelf.currentDevice.isOpen == false ) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf cancelSendTimer];
                self.mutleSendBtn.tag = 0;
                self.mutleSendBtn.title = NSLocalizedStringFromTable(@"lzK-xu-4Vr.title",@"Main", @"Delayed Send");
            });
            return;
        }
        sendFrame++;
        
        if (strongSelf.checkIdType == CheckIDTypeIncrease) {
            _frameId = [self increaseFrameIdHexString:_frameId];
            standardFrameData = [strongSelf buildStandardFrame:_frameId
                                                     frameData:_frameData
                                                        echoId:txc->echo_id];
        }
        if(strongSelf.checkDataType == CheckDataTypeIncrease) {
            _frameData = [self increaseFrameDataHexString:_frameData];
            standardFrameData = [strongSelf buildStandardFrame:_frameId
                                                     frameData:_frameData
                                                        echoId:txc->echo_id];
        }
        
    });
    
    dispatch_resume(_sendTimer);
    
    
    
    _mutleSendBtn.title = NSLocalizedStringFromTable(@"stop-send",@"Main",@"Stop Send");
}

- (void)cancelSendTimer {
    if (_sendTimer != nil) {
        dispatch_cancel(_sendTimer);
        _sendTimer = nil;
    }
}

- (struct innomaker_device_bittiming)getBittiming:(int)index {
    struct innomaker_device_bittiming bittming;
    
    switch (index) {
        case 0: // 20K
            bittming.prop_seg = 6;
            bittming.phase_seg1  = 7;
            bittming.phase_seg2 = 2;
            bittming.sjw = 1;
            bittming.brp = 150;
            break;
        case 1: // 33.33K
            bittming.prop_seg = 3;
            bittming.phase_seg1  = 3;
            bittming.phase_seg2 = 1;
            bittming.sjw = 1;
            bittming.brp = 180;
            break;
        case 2: // 40K
            bittming.prop_seg = 6;
            bittming.phase_seg1  = 7;
            bittming.phase_seg2 = 2;
            bittming.sjw = 1;
            bittming.brp = 75;
            break;
        case 3: // 50K
            bittming.prop_seg = 6;
            bittming.phase_seg1  = 7;
            bittming.phase_seg2 = 2;
            bittming.sjw = 1;
            bittming.brp = 60;
            break;
        case 4: // 66.66K
            bittming.prop_seg = 3;
            bittming.phase_seg1  = 3;
            bittming.phase_seg2 = 1;
            bittming.sjw = 1;
            bittming.brp = 90;
            break;
        case 5: // 80K
            bittming.prop_seg = 3;
            bittming.phase_seg1  = 3;
            bittming.phase_seg2 = 1;
            bittming.sjw = 1;
            bittming.brp = 75;
            break;
        case 6: // 83.33K
            bittming.prop_seg = 3;
            bittming.phase_seg1  = 3;
            bittming.phase_seg2 = 1;
            bittming.sjw = 1;
            bittming.brp = 72;
            break;
            
            
        case 7: // 100K
            bittming.prop_seg = 6;
            bittming.phase_seg1  = 7;
            bittming.phase_seg2 = 2;
            bittming.sjw = 1;
            bittming.brp = 30;
            break;
        case 8: // 125K
            bittming.prop_seg = 6;
            bittming.phase_seg1  = 7;
            bittming.phase_seg2 = 2;
            bittming.sjw = 1;
            bittming.brp = 24;
            break;
        case 9: // 200K
            bittming.prop_seg = 6;
            bittming.phase_seg1  = 7;
            bittming.phase_seg2 = 2;
            bittming.sjw = 1;
            bittming.brp = 15;
            break;
        case 10: // 250K
            bittming.prop_seg = 6;
            bittming.phase_seg1  = 7;
            bittming.phase_seg2 = 2;
            bittming.sjw = 1;
            bittming.brp = 12;
            break;
        case 11: // 400K
            bittming.prop_seg = 3;
            bittming.phase_seg1  = 3;
            bittming.phase_seg2 = 1;
            bittming.sjw = 1;
            bittming.brp = 15;
            break;
        case 12: // 500K
            bittming.prop_seg = 6;
            bittming.phase_seg1  = 7;
            bittming.phase_seg2 = 2;
            bittming.sjw = 1;
            bittming.brp = 6;
            break;
        case 13: // 666K
            bittming.prop_seg = 3;
            bittming.phase_seg1  = 3;
            bittming.phase_seg2 = 2;
            bittming.sjw = 1;
            bittming.brp = 8;
            break;
        case 14: /// 800K
            bittming.prop_seg = 7;
            bittming.phase_seg1  = 8;
            bittming.phase_seg2 = 4;
            bittming.sjw = 1;
            bittming.brp = 3;
            break;
        case 15: /// 1000K
            bittming.prop_seg = 5;
            bittming.phase_seg1  = 6;
            bittming.phase_seg2 = 4;
            bittming.sjw = 1;
            bittming.brp = 3;
            break;
        default: /// 1000K
            bittming.prop_seg = 5;
            bittming.phase_seg1  = 6;
            bittming.phase_seg2 = 4;
            bittming.sjw = 1;
            bittming.brp = 3;
            break;
    }
    return bittming;
}

#pragma mark - helper
/// Format string
/// @param originString origin string
/// @param charactersInString limit string
- (NSString *)formatString:(NSString *)originString charactersInString:(NSString *)charactersInString {
    NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:charactersInString];
    char *stringResult = malloc(originString.length * 2);
    int cpt = 0;
    for (int i = 0; i < [originString length]; i++) {
        unichar c = [originString characterAtIndex:i];
        if ([charSet characterIsMember:c]) {
            stringResult[cpt]=c;
            cpt++;
        }
    }
    stringResult[cpt]='\0';
    NSString *string = [NSString stringWithCString:stringResult encoding:NSUTF8StringEncoding];
    free(stringResult);
    return string;
}

/// Sperate every two char use space
/// @param number origin number string
- (NSString *)dealWithString:(NSString *)number
{
    char *chars = malloc(number.length * 2);
    int count = 0;
    int j = 0;
    
    for (int i = 0; i < number.length; i++) {
        count++;
        char c = [number characterAtIndex:i];
        chars[j++] = c;
        if (count == 2 && i < number.length - 1) {
            chars[j++] = ' ';
            count = 0;
        }
    }
    
    /// add end character
    chars[j] = '\0';
    NSString *formatString =  [NSString stringWithUTF8String:chars];
    free(chars);
    
    return formatString;
}

/// Limit textfield 16 binary system format
/// @param textField target textfield
/// @param limitLength limit length
/// @param spacePadding if use space to sperate
- (void)adjustTextFieldToHex:(NSTextField *)textField
                 limitLength:(int)limitLength
            needSpacePadding:(BOOL)spacePadding
{
    
    NSString *originString = textField.stringValue;
    if (spacePadding ) {
        originString = [textField.stringValue stringByReplacingOccurrencesOfString:@" " withString:@""];
    }
    NSString *string =  [self formatString:originString charactersInString:@"0123456789ABCDEFabcdef"];
    if (string.length > limitLength) {
        string = [string substringWithRange:NSMakeRange(0, limitLength)];
    }
    
    if (spacePadding) {
        string = [self dealWithString:string];
    }
    
    textField.stringValue = string;
}

/// Limit textfield number format
/// @param textField target textfield
/// @param minValue min value
/// @param maxValue max value
- (void)adjustTextFieldToNumber:(NSTextField *)textField
                       minValue:(int)minValue
                       maxValue:(int)maxValue {
    NSString *originString = [textField.stringValue stringByReplacingOccurrencesOfString:@" "
                                                                              withString:@""];
    NSString *string = [self formatString:originString charactersInString:@"0123456789"];
    int value = string.intValue;
    if (value < minValue) {
        string = [NSString stringWithFormat:@"%d", minValue];
    }
    if (value > maxValue) {
        string = [NSString stringWithFormat:@"%d", maxValue];
    }
    
    textField.stringValue = string;
}

/// Increase frame id
/// @param frameId frame id str
- (NSString *)increaseFrameIdHexString:(NSString *)frameId {
    NSMutableString *increaseFrameId = [NSMutableString string];
    
    NSArray *dataByte = [frameId componentsSeparatedByString:@" "];
    Byte frameIdBytes[dataByte.count];
    BOOL increaseBit = true;
    /// FrameID increase one inverted order
    for (int i = (int)dataByte.count - 1; i >= 0; i--) {
        NSString *byteValue = [dataByte objectAtIndex:i];
        frameIdBytes[i] = strtoul([byteValue UTF8String],0,16);
        if (increaseBit) {
            if (frameIdBytes[i] + 1 > 0xff) {
                frameIdBytes[i] = 0x00;
                increaseBit = true;
            }
            else {
                frameIdBytes[i] = frameIdBytes[i] + 1;
                increaseBit = false;
            }
        }
    }
    
    for (unsigned long i = 0; i < dataByte.count;i++) {
        [increaseFrameId appendFormat:@"%02x",frameIdBytes[i]];
        if (i != dataByte.count - 1) {
            [increaseFrameId appendString:@" "];
        }
    }
    return increaseFrameId;
}

/// Increase frame data
/// @param frameData frame data str
- (NSString *)increaseFrameDataHexString:(NSString*)frameData {
    NSMutableString *increaseFrameData = [NSMutableString string];
    Byte frameDataBytes[frameData.length];
    NSArray *dataByte = [frameData componentsSeparatedByString:@" "];
    BOOL increaseBit = true; /// increase one
    /// FrameData increase one in order
    for (int i = 0; i < dataByte.count; i++) {
        NSString *byteValue = [dataByte objectAtIndex:i];
        frameDataBytes[i] = strtoul([byteValue UTF8String],0,16);
        if (increaseBit) {
            if (frameDataBytes[i] + 1 > 0xff) {
                frameDataBytes[i] = 0x00;
                increaseBit = true;
            }
            else {
                frameDataBytes[i] = frameDataBytes[i] + 1;
                increaseBit = false;
            }
        }
    }
    
    for (unsigned long i = 0; i < dataByte.count;i ++) {
        [increaseFrameData appendFormat:@"%02x",frameDataBytes[i]];
        if (i != dataByte.count - 1) {
            [increaseFrameData appendString:@" "];
        }
    }
    return increaseFrameData;
}

/// Build standard frame
/// @param frameId frame id
/// @param frameData frame data
/// @return standard frame
- (NSData *)buildStandardFrame:(NSString *)frameId
                     frameData:(NSString *)frameData
                        echoId:(uint32_t)echoId{
    struct innomaker_host_frame frame;
    memset(&frame, 0, sizeof(frame));
    frame.echo_id = echoId;
    frame.can_id = frameId.intValue;
    frame.can_dlc = 8;
    frame.channel = 0;
    frame.flags = 0;
    frame.reserved = 0;
    
    NSArray *canIdByte = [frameId componentsSeparatedByString:@" "];
    Byte canId[4] = {0x00,0x00,0x00,0x00};
    
    /// Use Little Endian Mode (From High To Light)
    for (int i = 0; i < canIdByte.count; i++) {
        NSString  *b = canIdByte[i];
        canId[3 - i] = strtoul([b UTF8String],0,16);
    }
    memcpy(&frame.can_id, canId, 4);
    
    NSArray *dataByte = [frameData componentsSeparatedByString:@" "];
    for (int i = 0; i < dataByte.count; i++) {
        NSString *byteValue = [dataByte objectAtIndex:i];
        frame.data[i] = strtoul([byteValue UTF8String],0,16);
    }
    
    NSData *standardFrameData = [NSData dataWithBytes:&frame length:sizeof(frame)];
    NSLog(@"Standard Frame Data = %@",standardFrameData);
    return standardFrameData;
}


/// Convert Data to view model
/// @param data data
/// @param isIn direction
- (FrameViewModel *)dataToModel:(NSData *)data direction:(BOOL)isIn {
    if (data.length < 20) return [FrameViewModel new];
    
    Byte *dataByte = (Byte*)data.bytes;
    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc]init];
    timeFormatter.dateFormat = @"HH:mm:ss";
    NSString *dateString = [timeFormatter stringFromDate: [NSDate date]];
    
    FrameViewModel *model = [FrameViewModel new];
    model.seqID = [NSString stringWithFormat:@"%lu",(unsigned long)_recvFrame.count];
    model.systemTime = dateString;
    model.timeIdentifier = @"";
    model.canChannel = [NSString stringWithFormat:@"%d", dataByte[10]];
    model.direction =  isIn ? @"Recv" : @"Send";
    
    Byte frameId[4];
    frameId[0] = dataByte[4];
    frameId[1] = dataByte[5];
    frameId[2] = dataByte[6];
    frameId[3] = dataByte[7];
    uint32_t intFrameId = 0;
    memcpy(&intFrameId,frameId, 4);
    if (intFrameId > 0x7FF && isIn) {
        model.color = NSColor.systemRedColor;
        model.isDataValid = false;
    } else if (isIn){
        model.color = NSColor.systemGreenColor;
        model.isDataValid =  true;
    } else {
        model.color = NSColor.blackColor;
        model.isDataValid = true;
    }
    model.identifier = [NSString stringWithFormat:@"%04x",intFrameId];
    model.frameType = NSLocalizedStringFromTable(@"ee5-S7-16Z.title", @"Main", @"Data Frame")  ;
    model.frameFormat = NSLocalizedStringFromTable(@"DSs-f3-BWA.title", @"Main", @"Standard Frame")  ;
    model.length = @"8";
    
    NSData *frameData = [NSData dataWithBytes:dataByte + 12 length:8];
    model.data = [frameData hexString];
    return model;
}

- (NSString *)displayTextForColumn:(NSTableColumn *)tableColumn
                             model:(FrameViewModel *)model {
    NSDictionary *dictionary = @{
        @"SeqIdentifier": model.seqID,
        @"SystemTimeIdentifier":model.systemTime,
        @"TimeIdentifierIdenftifier":model.timeIdentifier,
        @"CanChannelIdentifier":model.canChannel,
        @"DirectionIdentifier":model.direction,
        @"IDIdentifier":model.identifier,
        @"FrameTypeIdentifier":model.frameType,
        @"FrameFormatIdentifier":model.frameFormat,
        @"FrameLengthIdentifier":model.length,
        @"FrameDataIdentifier":model.data
    };
    
    return dictionary[tableColumn.identifier];
}

- (NSTableCellView *)configColumnWithTable:(NSTableView *)tableView
                                     model:(FrameViewModel*)model
                                    column:(NSTableColumn *)tableColumn {
    
    NSString *displayText = [self displayTextForColumn:tableColumn model:model];
    NSTableCellView *cellView = [_tableView makeViewWithIdentifier:tableColumn.identifier owner:nil];
    if (cellView) {
        cellView.textField.textColor = model.color;
        cellView.textField.stringValue = displayText;
        return cellView;
    }
    return cellView;
}


/// Alert message
/// @param message message
- (void)alertWithMsg:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSWarningAlertStyle;
    [alert addButtonWithTitle: NSLocalizedStringFromTable(@"confirm-title", @"Main", @"Confirm")];
    alert.messageText = NSLocalizedStringFromTable(@"tip", @"Main", @"tip");
    alert.informativeText = message;
    
    [alert beginSheetModalForWindow:[NSApplication sharedApplication].keyWindow completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            
        } else if (returnCode == NSAlertSecondButtonReturn) {
            
        } else {
            
        }
    }];
}

- (BOOL)isScrollToBottom {
    return true;
}



- (void)exportLogFile
{
    NSWindow*       window = [NSApplication sharedApplication].keyWindow;
    NSSavePanel*    panel = [NSSavePanel savePanel];
    [panel setNameFieldStringValue:@"log.txt"];
    
    __weak typeof(self) weakSelf = self;
    [panel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  theFile = [panel URL];
            // Write the contents in the new format.
            NSMutableString *writeString = [NSMutableString string];
            for (FrameViewModel *model in weakSelf.recvFrame) {
                [writeString appendFormat:@"%@\n",model.presentString];
            }
            [writeString writeToURL:theFile atomically:true encoding:NSUTF8StringEncoding error:nil];
        }
    }];
}

#pragma mark - Echo buffer

/* 'allocate' a tx context.
 * returns a valid tx context or NULL if there is no space.
 */
static struct gs_tx_context *gs_alloc_tx_context(struct gs_can *dev) {
    
    int i = 0;
    
    OSSpinLockLock(&dev->tx_ctx_lock);
    for (; i < GS_MAX_TX_URBS; i++) {
        if (dev->tx_context[i].echo_id == GS_MAX_TX_URBS) {
            dev->tx_context[i].echo_id = i;
            NSLog(@"gs_alloc_tx_context %d",i);
            OSSpinLockUnlock(&dev->tx_ctx_lock);
            return &dev->tx_context[i];
        }
    }
    OSSpinLockUnlock(&dev->tx_ctx_lock);
    return NULL;
}


/* releases a tx context
 */
static void gs_free_tx_context(struct gs_tx_context *txc) {
    NSLog(@"gs_free_tx_context %d",txc->echo_id);
    txc->echo_id = GS_MAX_TX_URBS;
}


/* Get a tx context by id.
 */
static struct gs_tx_context *gs_get_tx_context(struct gs_can *dev,
                                               unsigned int id) {
    NSLog(@"gs_get_tx_context %d",id);
    if (id < GS_MAX_TX_URBS) {
        OSSpinLockLock(&dev->tx_ctx_lock);
        if (dev->tx_context[id].echo_id == id) {
            OSSpinLockUnlock(&dev->tx_ctx_lock);
            return &dev->tx_context[id];
        }
        OSSpinLockUnlock(&dev->tx_ctx_lock);
    }
    return NULL;
}

#pragma mark - notification
#pragma mark - getter and setter



@end
