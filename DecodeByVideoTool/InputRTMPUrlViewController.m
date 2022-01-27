//
//  TypeRTMPUrlViewController.m
//  DecodeByVideoTool
//
//  Created by 陈剑 on 2022/1/20.
//

#import "InputRTMPUrlViewController.h"
#import "DisplayViewController.h"

@interface InputRTMPUrlViewController ()
@property (nonatomic, strong) UITextView *textView;

@end

@implementation InputRTMPUrlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"InputRTMPUrl";
    self.textView = [[UITextView alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    [self.view addSubview:self.textView];
    self.view.backgroundColor = [UIColor whiteColor];

//    self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
//    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor blueColor],NSFontAttributeName: [UIFont systemFontOfSize:20]};
//    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(backAction:)];
    self.navigationController.navigationBar.translucent = NO;//设置导航栏透明度 NO表示不透明
    UIBarButtonItem *leftItem1 = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(backAction)];//设置一个系统Item
    self.navigationItem.leftBarButtonItem = leftItem1;//添加到导航项的左按钮

    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneAction)];//设置一个系统Item
    self.navigationItem.rightBarButtonItem = rightItem;




}

- (void)backAction {
    [self dismissViewControllerAnimated:YES completion:^{

    }];
}

- (void)doneAction {

    DisplayViewController *vc = [[DisplayViewController alloc]initWithUrl:[NSURL URLWithString:self.textView.text]];
    UINavigationController *navagationController = [[UINavigationController alloc]initWithRootViewController:vc];
    [self presentViewController:navagationController animated:YES completion:^{

    }];
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
