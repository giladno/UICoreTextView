//
//  CoreTextView.m
//
//  Created by Gilad Novik on 2013-01-10.
//  Copyright (c) 2013 Gilad Novik.
//
//  Distributed under the permissive zlib License
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import <objc/runtime.h>
#import <libxml/HTMLparser.h>
#import <CoreText/CoreText.h>
#import "CoreTextView.h"

#if! __has_feature(objc_arc)
#error This file requires ARC. Please set it explicitly using the '-fobjc-arc' flag
#endif

@implementation CoreTextView
{
	id m_frameSetter;
	NSMutableDictionary* m_links;
}
@synthesize attributedString=m_attributedString,contentInset=m_contentInset,delegate=m_delegate,debugBorders=m_debugBorders;

-(id)initWithFrame:(CGRect)frame
{
	if ((self=[super initWithFrame:frame])!=nil)
	{
		self.contentMode=UIViewContentModeRedraw;
		m_links=[[NSMutableDictionary alloc] initWithCapacity:2];
		[self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doLink:)]];
	}
	return self;
}

-(void)awakeFromNib
{
	[super awakeFromNib];
	self.contentMode=UIViewContentModeRedraw;
	m_links=[[NSMutableDictionary alloc] initWithCapacity:2];
	[self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doLink:)]];
}

- (void)drawRect:(CGRect)rect
{
	[m_links removeAllObjects];
	if (m_frameSetter==NULL)
		return;
	CGContextRef context=UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);
	CGContextSetTextMatrix(context,CGAffineTransformIdentity);
	CGContextConcatCTM(context, CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0f,self.bounds.size.height),1.0f,-1.0f));
	
	CGPathRef path=CGPathCreateWithRect(UIEdgeInsetsInsetRect(self.bounds,UIEdgeInsetsMake(m_contentInset.bottom, m_contentInset.left, m_contentInset.top, m_contentInset.right)),NULL);
	id frame=CFBridgingRelease(CTFramesetterCreateFrame((__bridge CTFramesetterRef)(m_frameSetter), CFRangeMake(0, 0), path, NULL));
	CTFrameDraw((__bridge CTFrameRef)(frame), context);
	
	NSArray* lines=(__bridge NSArray*)CTFrameGetLines((__bridge CTFrameRef)(frame));
	CGPoint* origins=(CGPoint*)alloca(sizeof(CGPoint)*lines.count);
	CTFrameGetLineOrigins((__bridge CTFrameRef)(frame), CFRangeMake(0, 0), origins);
	
	[lines enumerateObjectsUsingBlock:^(id line, NSUInteger lineIndex, BOOL* stop)
	 {
		 [(__bridge NSArray*)CTLineGetGlyphRuns((__bridge CTLineRef)(line)) enumerateObjectsUsingBlock:^(id run, NSUInteger index, BOOL* stop)
		  {
			  NSDictionary* attributes=(__bridge NSDictionary*)CTRunGetAttributes((__bridge CTRunRef)run);
			  CGRect bounds;
			  CGFloat ascent,descent;
			  bounds.size.width=CTRunGetTypographicBounds((__bridge CTRunRef)run, CFRangeMake(0,0), &ascent, &descent, NULL);
			  bounds=CGRectMake(origins[lineIndex].x+m_contentInset.left+CTLineGetOffsetForStringIndex((__bridge CTLineRef)(line), CTRunGetStringRange((__bridge CTRunRef)run).location, NULL), origins[lineIndex].y+m_contentInset.bottom-descent, bounds.size.width, ascent+descent);
			  
			  id refCon=(__bridge id)(CTRunDelegateGetRefCon((__bridge CTRunDelegateRef)([(__bridge NSDictionary*)CTRunGetAttributes((__bridge CTRunRef)run) valueForKey:(id)kCTRunDelegateAttributeName])));
			  
			  if (m_debugBorders)
			  {
				  CGContextSetFillColorWithColor(context,[UIColor colorWithRed:1 green:0 blue:0 alpha:0.3].CGColor);
				  CGContextFillRect(context, bounds);
			  }
			  if ([refCon conformsToProtocol:@protocol(HTMLRenderer)] && [refCon respondsToSelector:@selector(renderInContext:rect:)])
			  {
				  CGContextSaveGState(context);
				  [refCon renderInContext:context rect:bounds];
				  CGContextRestoreGState(context);
			  }
			  else if ([refCon isKindOfClass:[NSNumber class]])	// hr
			  {
				  bounds.size.width=UIEdgeInsetsInsetRect(self.bounds, m_contentInset).size.width;
				  bounds.size.height=[refCon floatValue]+descent;
				  bounds.origin.x=m_contentInset.left;
				  bounds.origin.y-=CTFontGetSize((__bridge CTFontRef)[attributes valueForKey:(id)kCTFontAttributeName])/2.0f-ascent;
				  
				  CGContextSetFillColorWithColor(context,(__bridge CGColorRef)[attributes valueForKey:(id)kCTForegroundColorAttributeName]);
				  CGContextFillRect(context, bounds);
			  }
			  else if (attributes[@"image"])
			  {
				  CGContextDrawImage(context, bounds, [attributes[@"image"] CGImage]);
			  }
			  if (attributes[@"href"])
			  {
				  [m_links setObject:attributes[@"href"] forKey:[NSValue valueWithCGRect:CGRectMake(bounds.origin.x, self.bounds.size.height-(bounds.origin.y+bounds.size.height)-descent, bounds.size.width, bounds.size.height)]];
			  }
			  if (m_debugBorders)
			  {
				  CGContextSetFillColorWithColor(context,[UIColor blackColor].CGColor);
				  CGContextStrokeRect(context, bounds);
			  }
		  }];
	 }];
	CGPathRelease(path);
	CGContextRestoreGState(context);
}

-(void)setAttributedString:(NSAttributedString*)attributedString
{
	if (m_attributedString==attributedString)
		return;
	m_frameSetter=(m_attributedString=attributedString)!=nil ? CFBridgingRelease(CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attributedString)) : nil;
	[self setNeedsDisplay];
}

-(CGSize)sizeThatFits:(CGSize)size
{
	size=m_frameSetter ? CTFramesetterSuggestFrameSizeWithConstraints((__bridge CTFramesetterRef)(m_frameSetter), CFRangeMake(0, 0), NULL, CGSizeMake(size.width, CGFLOAT_MAX), NULL) : CGSizeZero;
	size.width+=m_contentInset.left+m_contentInset.right;
	size.height+=m_contentInset.top+m_contentInset.bottom;
	return CGSizeMake(ceilf(size.width), ceilf(size.height));
}
-(void)doLink:(UIGestureRecognizer*)gesture
{
	if (gesture.state!=UIGestureRecognizerStateRecognized)
		return;
	CGPoint point=[gesture locationInView:self];
	[m_links enumerateKeysAndObjectsUsingBlock:^(NSValue* key, NSURL* url, BOOL* stop)
	{
		if (CGRectContainsPoint(key.CGRectValue, point))
		{
			if ([m_delegate respondsToSelector:@selector(coreTextView:openURL:)] && [m_delegate coreTextView:self openURL:url])
				return;
			[[UIApplication sharedApplication] openURL:url];
			*stop=YES;
		}
	}];
}
@end

template<typename T> struct RunDelegateT : CTRunDelegateCallbacks
{
	RunDelegateT()
	{
		version=kCTRunDelegateVersion1;
		getAscent=T::ascent;
		getDescent=T::descent;
		getWidth=T::width;
		dealloc=_dealloc;
	}
	
	CTRunDelegateRef create(id refCon)
	{
		return CTRunDelegateCreate(this,(void*)CFBridgingRetain(refCon));
	}
	
	static CGFloat descent(void* ref)
	{
		return 0.0;
	}
	
	static CGFloat width(void* ref)
	{
		return 0.0f;
	}
	
	static void _dealloc(void* refCon)
	{
		CFBridgingRelease(refCon);
	}
};

@implementation HTMLParser
{
	htmlSAXHandler m_handler;
	NSMutableAttributedString* m_attributedString;
	NSMutableArray* m_style;
	CTParagraphStyleSetting m_paragraph[kCTParagraphStyleSpecifierCount];
}
@synthesize rendererHandler=m_rendererHandler;
-(id)init
{
	if ((self=[super init])!=nil)
	{
		xmlSAX2InitHtmlDefaultSAXHandler(&m_handler);
		
		struct callbacks
		{
			static void startElement(HTMLParser* parser, const xmlChar* name,const xmlChar** atts)
			{
				[parser->m_style addObject:[NSMutableDictionary dictionaryWithDictionary:parser->m_style.lastObject]];
				[parser->m_style.lastObject removeObjectsForKeys:@[@"width",@"height"]];	// this shoulb be specific to each tag
				
				if (xmlStrcasecmp(name,BAD_CAST"u")==0)
				{
					[parser->m_style.lastObject setValue:@(kCTUnderlineStyleSingle) forKey:(id)kCTUnderlineStyleAttributeName];
				}
				else if (xmlStrcasecmp(name,BAD_CAST"s")==0)
				{
					[parser->m_style.lastObject setValue:@(3.0f) forKey:(id)kCTStrokeWidthAttributeName];
				}
				else if (xmlStrcasecmp(name,BAD_CAST"a")==0)
				{
					[parser->m_style.lastObject setValue:(id)[UIColor blueColor].CGColor forKey:(id)kCTForegroundColorAttributeName];
					[parser->m_style.lastObject setValue:@(kCTUnderlineStyleSingle) forKey:(id)kCTUnderlineStyleAttributeName];
				}
				
				if (atts)
				{
					for (const xmlChar* key;(key=*atts++);)
					{
						const xmlChar* value=*atts++;
						if (xmlStrcasecmp(key,BAD_CAST"color")==0)
						{
							uint8_t r,g,b;
							CGFloat a=1.0f;
							if (sscanf((const char*)value, "#%2hhx%2hhx%2hhx",&r,&g,&b)==3 || sscanf((const char*)value, "rgb(%hhu,%hhu,%hhu)",&r,&g,&b)==3 || sscanf((const char*)value, "rgba(%hhu,%hhu,%hhu,%f)",&r,&g,&b,&a)==4)
							{
								UIColor* color=[UIColor colorWithRed:((CGFloat)r)/255.0f green:((CGFloat)g)/255.0f blue:((CGFloat)b)/255.0f alpha:a];
								if (xmlStrcasecmp(name,BAD_CAST"s")==0)
								{
									[parser->m_style.lastObject setValue:(id)color.CGColor forKey:(id)kCTStrokeColorAttributeName];
								}
								else
								{
									[parser->m_style.lastObject setValue:(id)color.CGColor forKey:(id)kCTForegroundColorAttributeName];
								}
							}
						}
						else if (xmlStrcasecmp(key,BAD_CAST"size")==0)
						{
							[parser->m_style.lastObject setValue:@(strtod((const char*)value, NULL)) forKey:@"size"];
						}
						else if (xmlStrcasecmp(key,BAD_CAST"traits")==0 || xmlStrcasecmp(key,BAD_CAST"image")==0)	// reserved - don't allow to override
						{
							continue;
						}
						else if (xmlStrcasecmp(key,BAD_CAST"style")==0 && xmlStrcasecmp(name,BAD_CAST"u")==0)
						{
							if (xmlStrcasecmp(value,BAD_CAST"none")==0)
							{
								[parser->m_style.lastObject setValue:@(kCTUnderlineStyleNone) forKey:(id)kCTUnderlineStyleAttributeName];
							}
							else if (xmlStrcasecmp(value,BAD_CAST"thick")==0)
							{
								[parser->m_style.lastObject setValue:@(kCTUnderlineStyleThick) forKey:(id)kCTUnderlineStyleAttributeName];
							}
							else if (xmlStrcasecmp(value,BAD_CAST"double")==0)
							{
								[parser->m_style.lastObject setValue:@(kCTUnderlineStyleDouble) forKey:(id)kCTUnderlineStyleAttributeName];
							}
						}
						else if (xmlStrcasecmp(key,BAD_CAST"width")==0 && xmlStrcasecmp(name,BAD_CAST"s")==0)
						{
							[parser->m_style.lastObject setValue:@(strtod((const char*)value, NULL)) forKey:(id)kCTStrokeWidthAttributeName];
						}
						else if (xmlStrcasecmp(key,BAD_CAST"src")==0 && xmlStrcasecmp(name,BAD_CAST"a")==0)
						{
							[parser->m_style.lastObject setValue:[NSURL URLWithString:[NSString stringWithUTF8String:(const char*)value]] forKey:@"src"];
						}
						else if (xmlStrcasecmp(key,BAD_CAST"src")==0 && xmlStrcasecmp(name,BAD_CAST"img")==0)
						{
							UIImage* image=nil;
							if (xmlStrstr(value,BAD_CAST"://")!=NULL)
							{
								if (xmlStrncasecmp(value,BAD_CAST"file://",7)==0)
								{
									image=[UIImage imageWithContentsOfFile:[[NSURL URLWithString:[NSString stringWithUTF8String:(const char*)value]] path]];
								}
								else
								{
									[parser->m_style.lastObject setValue:[NSURL URLWithString:[NSString stringWithUTF8String:(const char*)value]] forKey:@"src"];
								}
							}
							else if (xmlStrncasecmp(value,BAD_CAST"base64:",7)==0)
							{
								value+=7;
								static unsigned char base64[256] =
								{
									65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
									65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
									65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 62, 65, 65, 65, 63,
									52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 65, 65, 65, 65, 65, 65,
									65,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
									15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 65, 65, 65, 65, 65,
									65, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
									41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 65, 65, 65, 65, 65,
									65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
									65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
									65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
									65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
									65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
									65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
									65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
									65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
								};
								NSMutableData* data=[NSMutableData dataWithLength:((xmlStrlen(value)+3)/4)*3];
								uint8_t* output=(uint8_t*)data.mutableBytes;
								while (*value)
								{
									uint8_t accumulate[4];
									size_t i=0;
									while (*value && i<4)
									{
										accumulate[i++]=base64[*value++];
									}
									if(i >= 2)
										*output++ = (accumulate[0] << 2) | (accumulate[1] >> 4);
									if(i >= 3)
										*output++ = (accumulate[1] << 4) | (accumulate[2] >> 2);
									if(i >= 4)
										*output++ = (accumulate[2] << 6) | accumulate[3];
								}
								[data setLength:output-(const uint8_t*)data.bytes];
								image=[UIImage imageWithData:data];
							}
							else
							{
								image=[UIImage imageNamed:[NSString stringWithUTF8String:(const char*)value]];
							}
							[parser->m_style.lastObject setValue:image forKey:@"image"];
						}
						else if (xmlStrcasecmp(key,BAD_CAST"href")==0)
						{
							if (xmlStrcasecmp(name,BAD_CAST"a")!=0)
								continue;
							NSString* href=[NSString stringWithUTF8String:(const char*)value];
							NSURL* url=[NSURL URLWithString:href];
							if (url.scheme==nil)
							{
								if (href.length && [[NSCharacterSet characterSetWithCharactersInString:@"+0123456789"] characterIsMember:[href characterAtIndex:0]])
									url=[NSURL URLWithString:[@"tel://" stringByAppendingString:href]];
								else
									url=[NSURL URLWithString:[@"http://" stringByAppendingString:href]];
							}
							[parser->m_style.lastObject setValue:url forKey:@"href"];
						}
						else if (xmlStrcasecmp(key,BAD_CAST"width")==0 || xmlStrcasecmp(key,BAD_CAST"width")==0 || xmlStrcasecmp(key,BAD_CAST"descent")==0)
						{
							[parser->m_style.lastObject setValue:@(strtof((const char*)value, NULL)) forKey:[NSString stringWithUTF8String:(const char*)key]];
						}
						else
						{
							[parser->m_style.lastObject setValue:[NSString stringWithUTF8String:(const char*)value] forKey:[NSString stringWithUTF8String:(const char*)key]];
						}
					}
				}
				
				if (xmlStrcasecmp(name,BAD_CAST"b")==0)
				{
					[parser->m_style.lastObject setValue:@([parser->m_style.lastObject[@"traits"] unsignedIntegerValue]|kCTFontBoldTrait) forKey:@"traits"];
				}
				else if (xmlStrcasecmp(name,BAD_CAST"i")==0)
				{
					[parser->m_style.lastObject setValue:@([parser->m_style.lastObject[@"traits"] unsignedIntegerValue]|kCTFontItalicTrait) forKey:@"traits"];
				}
				
				size_t paragraph=0;
				for (NSString* key in [parser->m_style.lastObject allKeys])
				{
					NSString* value=[parser->m_style.lastObject valueForKey:key];
					if ([key isEqualToString:@"align"])
					{
						parser->m_paragraph[paragraph].spec=kCTParagraphStyleSpecifierAlignment;
						parser->m_paragraph[paragraph].value=alloca(parser->m_paragraph[paragraph].valueSize=sizeof(CTTextAlignment));
						if ([value isEqualToString:@"left"])
							*((CTTextAlignment*)parser->m_paragraph[paragraph].value)=kCTTextAlignmentLeft;
						else if ([value isEqualToString:@"right"])
							*((CTTextAlignment*)parser->m_paragraph[paragraph].value)=kCTTextAlignmentRight;
						else if ([value isEqualToString:@"center"])
							*((CTTextAlignment*)parser->m_paragraph[paragraph].value)=kCTTextAlignmentCenter;
						else if ([value isEqualToString:@"justified"])
							*((CTTextAlignment*)parser->m_paragraph[paragraph].value)=kCTTextAlignmentJustified;
						else
							*((CTTextAlignment*)parser->m_paragraph[paragraph].value)=kCTTextAlignmentNatural;
						++paragraph;
					}
					else if ([key isEqualToString:@"direction"])
					{
						parser->m_paragraph[paragraph].spec=kCTParagraphStyleSpecifierBaseWritingDirection;
						parser->m_paragraph[paragraph].value=alloca(parser->m_paragraph[paragraph].valueSize=sizeof(CTWritingDirection));
						if ([value isEqualToString:@"ltr"])
							*((CTWritingDirection*)parser->m_paragraph[paragraph].value)=kCTWritingDirectionLeftToRight;
						else if ([value isEqualToString:@"rtl"])
							*((CTWritingDirection*)parser->m_paragraph[paragraph].value)=kCTWritingDirectionRightToLeft;
						else
							*((CTWritingDirection*)parser->m_paragraph[paragraph].value)=kCTWritingDirectionNatural;
						++paragraph;
					}
					else if ([key isEqualToString:@"wrap"])
					{
						parser->m_paragraph[paragraph].spec=kCTParagraphStyleSpecifierLineBreakMode;
						parser->m_paragraph[paragraph].value=alloca(parser->m_paragraph[paragraph].valueSize=sizeof(CTLineBreakMode));
						if ([value isEqualToString:@"break-word"])
							*((CTLineBreakMode*)parser->m_paragraph[paragraph].value)=kCTLineBreakByCharWrapping;
						else if ([value isEqualToString:@"clip"])
							*((CTLineBreakMode*)parser->m_paragraph[paragraph].value)=kCTLineBreakByClipping;
						else if ([value isEqualToString:@"ellipsis-head"])
							*((CTLineBreakMode*)parser->m_paragraph[paragraph].value)=kCTLineBreakByTruncatingHead;
						else if ([value isEqualToString:@"ellipsis-tail"] || [value isEqualToString:@"ellipsis"])
							*((CTLineBreakMode*)parser->m_paragraph[paragraph].value)=kCTLineBreakByTruncatingTail;
						else if ([value isEqualToString:@"ellipsis-middle"])
							*((CTLineBreakMode*)parser->m_paragraph[paragraph].value)=kCTLineBreakByTruncatingMiddle;
						else
							*((CTLineBreakMode*)parser->m_paragraph[paragraph].value)=kCTLineBreakByWordWrapping;
						++paragraph;
					}
					else if ([key isEqualToString:@"font"])
					{
						CTFontSymbolicTraits traits=[parser->m_style.lastObject[@"traits"] unsignedIntegerValue];
						CGFloat size=[parser->m_style.lastObject[@"size"] floatValue];
						NSString* name=[value stringByAppendingFormat:@"%c%c%g",(traits & kCTFontTraitBold) ? 'B' : '-',(traits & kCTFontTraitItalic) ? 'I' : '-',size];
						static NSCache* cache=nil;
						static dispatch_once_t onceToken;
						dispatch_once(&onceToken, ^{
							cache=[[NSCache alloc] init];
						});
						id font=[cache objectForKey:name];
						if (font==nil && (font=CFBridgingRelease(CTFontCreateWithFontDescriptor((__bridge CTFontDescriptorRef)(CFBridgingRelease(CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)(@{(id)kCTFontFamilyNameAttribute:value,(id)kCTFontTraitsAttribute:@{(id)kCTFontSymbolicTrait:@(traits)}})))),size,NULL)))==nil)
						{
							continue;
						}
						[parser->m_style.lastObject setValue:font forKey:(id)kCTFontAttributeName];
					}
				}
				
				if (paragraph)
				{
					[parser->m_style.lastObject setValue:CFBridgingRelease(CTParagraphStyleCreate(parser->m_paragraph,paragraph)) forKey:(id)kCTParagraphStyleAttributeName];
				}
				
				if (xmlStrcasecmp(name,BAD_CAST"br")==0)
				{
					[parser->m_attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\r\n" attributes:parser->m_style.lastObject]];
				}
				else if (xmlStrcasecmp(name,BAD_CAST"hr")==0)
				{
					struct hr_delegate : RunDelegateT<hr_delegate>
					{
						static CGFloat ascent(void* ref)
						{
							return [(__bridge NSNumber*)ref floatValue];
						}
					};
					NSString* height=[parser->m_style.lastObject valueForKey:@"height"];
					NSMutableDictionary* attributes=[NSMutableDictionary dictionaryWithDictionary:parser->m_style.lastObject];
					[attributes setValue:CFBridgingRelease(hr_delegate().create([NSNumber numberWithFloat:height ? height.floatValue : 1.0f])) forKey:(id)kCTRunDelegateAttributeName];
					[parser->m_attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\r" attributes:attributes]];
				}
				else if (xmlStrcasecmp(name,BAD_CAST"img")==0)
				{
					struct image_delegate : RunDelegateT<image_delegate>
					{
						static CGFloat descent(void* ref)
						{
							NSMutableDictionary* style=(__bridge NSMutableDictionary*)ref;
							NSNumber* descent=style[@"descent"];
							if (descent==nil)
							{
								descent=@(0.0f);
								CTFontRef font=(__bridge CTFontRef)style[(id)kCTFontAttributeName];
								if (font)
								{
									if ([style[@"valign"] isEqualToString:@"middle"])
									{
										descent=@((height(ref)-CTFontGetSize(font))/2.0f);
									}
								}
								[style setValue:descent forKey:@"descent"];
							}
							return descent.floatValue;
						}
						static CGFloat ascent(void* ref)
						{
							return height(ref)-descent(ref);
						}
						static CGFloat width(void* ref)
						{
							NSMutableDictionary* style=(__bridge NSMutableDictionary*)ref;
							NSNumber* width=style[@"width"];
							if (width==nil)
							{
								width=@([style[@"image"] size].width);
								[style setValue:width forKey:@"width"];
							}
							return width.floatValue;
						}
						static CGFloat height(void* ref)
						{
							NSMutableDictionary* style=(__bridge NSMutableDictionary*)ref;
							NSNumber* height=style[@"height"];
							if (height==nil)
							{
								height=@([style[@"image"] size].height);
								[style setValue:height forKey:@"height"];
							}
							return height.floatValue;
						}
					};
					NSMutableDictionary* attributes=[NSMutableDictionary dictionaryWithDictionary:parser->m_style.lastObject];
					[attributes setValue:CFBridgingRelease(image_delegate().create(attributes)) forKey:(id)kCTRunDelegateAttributeName];
					[parser->m_attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\ufffc" attributes:attributes]];
				}
				else if (xmlStrcasecmp(name,BAD_CAST"div")==0)
				{
					struct div_delegate : RunDelegateT<div_delegate>
					{
						static CGFloat descent(void* ref)
						{
							id<HTMLRenderer> renderer=(__bridge id<HTMLRenderer>)ref;
							return [renderer respondsToSelector:@selector(descent)] ? renderer.descent : 0.0f;
						}
						static CGFloat ascent(void* ref)
						{
							id<HTMLRenderer> renderer=(__bridge id<HTMLRenderer>)ref;
							return [renderer respondsToSelector:@selector(ascent)] ? renderer.ascent : (height(ref)-descent(ref));
						}
						static CGFloat width(void* ref)
						{
							return ((__bridge id<HTMLRenderer>)ref).size.width;
						}
						static CGFloat height(void* ref)
						{
							return ((__bridge id<HTMLRenderer>)ref).size.height;
						}
					};
					NSMutableDictionary* attributes=[NSMutableDictionary dictionaryWithDictionary:parser->m_style.lastObject];
					id<HTMLRenderer> render=parser->m_rendererHandler ? parser->m_rendererHandler(attributes) : nil;
					if (render)
					{
						[attributes setValue:CFBridgingRelease(div_delegate().create(render)) forKey:(id)kCTRunDelegateAttributeName];
						[parser->m_attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\ufffc" attributes:attributes]];
					}
				}
			}
			static void endElement(HTMLParser* parser, const xmlChar* name)
			{
				[parser->m_style removeLastObject];
			}
			static void characters(HTMLParser* parser, const xmlChar *chars, int len)
			{
				[parser->m_attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:[[NSString alloc] initWithBytes:chars length:len encoding:NSUTF8StringEncoding] attributes:parser->m_style.lastObject]];
			}
			static void endDocument(HTMLParser* parser)
			{
				if (parser->m_attributedString.length && [parser->m_attributedString attributesAtIndex:parser->m_attributedString.length-1 effectiveRange:NULL][(id)kCTRunDelegateAttributeName]!=nil)
				{
					// special case - need to add a dummy character or else we'll lose the latest item
					[parser->m_attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\r" attributes:nil]];
				}
			}
			static void error(HTMLParser* parser, const char* msg, ...)
			{
				va_list va;
				va_start(va, msg);
				vfprintf(stderr, msg, va);
				va_end(va);
			}
		};
		m_handler.startDocument=NULL;
		m_handler.endDocument=(endDocumentSAXFunc)callbacks::endDocument;
		m_handler.startElement=(startElementSAXFunc)callbacks::startElement;
		m_handler.endElement=(endElementSAXFunc)callbacks::endElement;
		m_handler.characters=(charactersSAXFunc)callbacks::characters;
		m_handler.comment=NULL;
		m_handler.cdataBlock=NULL;
		m_handler.error=(errorSAXFunc)callbacks::error;
		
		m_style=[NSMutableArray arrayWithCapacity:4];
	}
	return self;
}
-(NSAttributedString*)parse:(NSString*)html
{
	NSData* data=[html dataUsingEncoding:NSUTF8StringEncoding];
	if (data)
	{
		htmlParserCtxtPtr context=htmlCreatePushParserCtxt(&m_handler, (__bridge void *)(self), (const char*)data.bytes, data.length, NULL, XML_CHAR_ENCODING_UTF8);
		if (context)
		{
			htmlCtxtUseOptions(context, HTML_PARSE_RECOVER|HTML_PARSE_NOERROR|HTML_PARSE_NOWARNING|HTML_PARSE_NONET|HTML_PARSE_COMPACT|HTML_PARSE_NOBLANKS);
			m_attributedString=[[NSMutableAttributedString alloc] init];
			[m_style setArray:@[@{@"font":@"Helvetica",@"size":@([UIFont systemFontSize])}]];
			if (htmlParseDocument(context)==0)
			{
				htmlFreeParserCtxt(context);
				return m_attributedString;
			}
			htmlFreeParserCtxt(context);
		}
	}
	return nil;
}
@end

@implementation NSAttributedString (CTHTML)

+(NSAttributedString*)attributedStringWithHTML:(NSString*)html
{
	return [self attributedStringWithHTML:html renderer:nil];
}
+(NSAttributedString*)attributedStringWithHTML:(NSString*)html renderer:(id<HTMLRenderer> (^)(NSMutableDictionary* attributes))renderer
{
	HTMLParser* parser=[[HTMLParser alloc] init];
	parser.rendererHandler=renderer;
	return [parser parse:html];
}
@end