//
//  ViewController.m
//  UICoreTextView
//
//  Created by Gilad Novik on 2013-01-17.
//  Copyright (c) 2013 Gilad Novik. All rights reserved.
//

#import "ViewController.h"
#import "CoreTextView.h"

@interface CustomRenderer : NSObject<HTMLRenderer>
@property(nonatomic,assign) CGSize size;
@property(nonatomic,copy) NSString* type;
@end

@implementation ViewController
{
	CoreTextView* m_coreText;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	m_coreText=[[CoreTextView alloc] initWithFrame:CGRectZero];
	m_coreText.backgroundColor=[UIColor clearColor];
	m_coreText.contentInset=UIEdgeInsetsMake(10, 10, 10, 10);
	
	NSString* html=[NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"view" ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];
	NSLog(@"%@",html);
	m_coreText.attributedString=[NSAttributedString attributedStringWithHTML:html renderer:^id<HTMLRenderer>(NSMutableDictionary* attributes)
	{
		CustomRenderer* renderer=[[CustomRenderer alloc] init];
		renderer.type=attributes[@"type"];
		renderer.size=CGSizeMake(16, 16);
		return renderer;
	}];
	m_coreText.frame=CGRectMake(0, 0, self.view.bounds.size.width, [m_coreText sizeThatFits:CGSizeMake(self.view.bounds.size.width, MAXFLOAT)].height);
	
	UIScrollView* scroll=[[UIScrollView alloc] initWithFrame:self.view.bounds];
	scroll.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	scroll.contentSize=m_coreText.frame.size;
	[scroll addSubview:m_coreText];
	[self.view addSubview:scroll];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

@implementation CustomRenderer
-(void)renderInContext:(CGContextRef)context rect:(CGRect)rect
{
	if ([self.type isEqualToString:@"circle"])
	{
		CGContextSetFillColorWithColor(context, [UIColor blueColor].CGColor);
		CGContextFillEllipseInRect(context, rect);
	}
	else if ([self.type isEqualToString:@"square"])
	{
		CGContextSetFillColorWithColor(context, [UIColor blueColor].CGColor);
		CGContextFillRect(context, rect);
	}
}
@end
