//
//  ViewController.m
//  UICoreTextView
//
//  Created by Gilad Novik on 2013-01-17.
//  Copyright (c) 2013 Gilad Novik. All rights reserved.
//

#import "ViewController.h"
#import "UICoreTextView.h"

@interface CustomRenderer : NSObject<HTMLRenderer>
@property(nonatomic,assign) CGSize size;
@property(nonatomic,copy) NSString* type;
@end

@implementation ViewController
{
	UICoreTextView* m_coreText;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	m_coreText=[[UICoreTextView alloc] initWithFrame:self.view.bounds];
	m_coreText.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
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
	[self.view addSubview:m_coreText];
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
