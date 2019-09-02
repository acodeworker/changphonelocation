//
//  ViewController.m
//  003---资源共享
//
//  Created by Cooci on 2018/6/19.
//  Copyright © 2018年 Cooci. All rights reserved.
//

#import "ViewController.h"
#import <MapKit/MapKit.h>

@interface ViewController ()<CLLocationManagerDelegate>
@property (nonatomic, assign) NSInteger tickets;
@property (nonatomic, strong) NSMutableArray *mArray;
@property (nonatomic, copy)   NSString *name;

@property (nonatomic, strong) NSLock *lock;

/* 获取当前定位 */
@property (nonatomic, strong) CLLocationManager * locationManager;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
 }

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {

//    // 1. 开启一条售票线程
//    NSThread *t1 = [[NSThread alloc] initWithTarget:self selector:@selector(startAtimer) object:nil];
//    t1.name = @"售票 A";
//    [t1 start];
//
//    // 2. 再开启一条售票线程
//    NSThread *t2 = [[NSThread alloc] initWithTarget:self selector:@selector(bstartAtimer) object:nil];
//    t2.name = @"售票 B";
//    [t2 start];

//    [self initTicketStatusSave];
    
    
    //定位
    
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.distanceFilter = 100000.0f;
    if ([[[UIDevice currentDevice]systemVersion] doubleValue] >8.0){
        [self.locationManager requestWhenInUseAuthorization];
    }
    
    [self.locationManager startUpdatingLocation];
    
    
    
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
    
    CLLocation *location = [locations lastObject];
    //geo获得城市名、国家代码
    __weak typeof(self) weakSelf = self;
    [[[CLGeocoder alloc] init] reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (placemarks.count > 0) {
            CLPlacemark *place = [placemarks lastObject];
            NSString *cityName = [NSString stringWithFormat:@"%@%@%@", place.locality,place.subLocality,place.name];
 
//            NSString *countryCode = [NSString stringWithFormat:@"%@",place.administrativeArea];
//            NSLog(@"%@",place);
            dispatch_async(dispatch_get_main_queue(), ^{
//
//                UIAlertController* aler = [UIAlertController alertControllerWithTitle:@"当前地址" message:cityName preferredStyle:UIAlertControllerStyleAlert];
//                [weakSelf presentViewController:aler animated:YES completion:nil];
                UIAlertView* alert = [[UIAlertView alloc]initWithTitle:@"当前地址" message:cityName delegate:self cancelButtonTitle:@"知道了" otherButtonTitles: nil];
                [alert show];
                
            });

           
            
            
        }
    }];
    
    
    
    [manager stopUpdatingLocation];
}



/**
 * 线程安全：使用 NSLock 加锁
 * 初始化火车票数量、卖票窗口(线程安全)、并开始卖票
 */

- (void)initTicketStatusSave {
    NSLog(@"currentThread---%@",[NSThread currentThread]); // 打印当前线程
    
    self.tickets = 10;

    self.lock = [[NSLock alloc] init];  // 初始化 NSLock 对象
    
    // 1.创建 queue1,queue1 代表北京火车票售卖窗口
    NSOperationQueue *queue1 = [[NSOperationQueue alloc] init];
    queue1.maxConcurrentOperationCount = 1;
    
    // 2.创建 queue2,queue2 代表上海火车票售卖窗口
    NSOperationQueue *queue2 = [[NSOperationQueue alloc] init];
    queue2.maxConcurrentOperationCount = 1;
    
    // 3.创建卖票操作 op1
    NSBlockOperation *op1 = [NSBlockOperation blockOperationWithBlock:^{
        [self startAtimer];
    }];
    
    // 4.创建卖票操作 op2
    NSBlockOperation *op2 = [NSBlockOperation blockOperationWithBlock:^{
        [self bstartAtimer];
    }];
    
    // 5.添加操作，开始卖票
    [queue1 addOperation:op1];
    [queue2 addOperation:op2];
    
    
 }

/**
 * 售卖火车票(线程安全)
 */
- (void)saleTicketSafe {
 
        // 加锁
        [self.lock lock];
        
        if (self.tickets > 0) {
            //如果还有票，继续售卖
            self.tickets--;
            NSLog(@"%@", [NSString stringWithFormat:@"剩余票数:%d 窗口:%@", self.tickets, [NSThread currentThread]]);
            [NSThread sleepForTimeInterval:0.2];
        }
        
        // 解锁
    
    
        [self.lock unlock];
        
    if (self.tickets <= 0) {
        NSLog(@"所有火车票均已售完");
//        [NSThread exit];//这里会死锁崩溃。
    }
}







- (void)startAtimer{
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self saleTicketSafe];
    }];
    [[NSRunLoop currentRunLoop]run];//子线程默认不开启
}

- (void)bstartAtimer{
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self saleTicketSafe];
    }];
    [[NSRunLoop currentRunLoop]run];//子线程默认不开启
}


// 售票接口
- (void)saleTickets {
    
    // runloop & 线程 不是一一对应
    
         // 0. 模拟延时
        
        //NSObject *obj = [[NSObject alloc] init];
        //obj 是自己的临时对象,对其他访问该区域的无影响
        //可以锁self 那么访问该方法的时候所有的都锁住,可以根据需求特定锁
        @synchronized(self){
            // 递归 非递归
//            [NSThread sleepForTimeInterval:1];
            // 1. 判断是否还有票
            if (self.tickets > 0) {
                // 2. 如果有票，卖一张，提示用户
                self.tickets--;
                NSLog(@"剩余票数 %zd %@", self.tickets, [NSThread currentThread]);
            } else {
                // 3.如果没票，退出循环
                NSLog(@"没票了，来晚了 %@", [NSThread currentThread]);
                [NSThread exit];// 退出线程--结果runloop也停止了
            }
            
            //在锁里面操作其他的变量的影响
//            [self.mArray addObject:[NSDate date]];
//            NSLog(@"%@ *** %@",[NSThread currentThread],self.mArray);
        }
 
}

#pragma mark - lazy

- (NSMutableArray *)mArray{
    if (!_mArray) {
        _mArray = [NSMutableArray arrayWithCapacity:10];
    }
    return _mArray;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}





@end
