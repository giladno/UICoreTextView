UICoreTextView
==============

<img src='https://raw.github.com/giladno/UICoreTextView/gh-pages/images/screenshot.png' />

# Overview
iOS controls (such as [UILabel](http://developer.apple.com/library/ios/#documentation/uikit/reference/UILabel_Class/Reference/UILabel.html#//apple_ref/occ/instp/UILabel/attributedText) and [UITextView](http://developer.apple.com/library/ios/#documentation/uikit/reference/uitextview_class/Reference/UITextView.html#//apple_ref/occ/instp/UITextView/attributedText)) already support NSAttributedString, but UICoreTextView offers much more than simple styling.
If your app needs to render both text & images, or have some custom rendering on the fly - then UICoreTextView is for you.

There is another great core text library by Oliver Drobnik: <a href='https://github.com/Cocoanetics/DTCoreText'>DTCoreText</a>. My goal was to create a very tiny and easy to use component (2 files only!) which is meant for simple tasks. If you really need full control of your output, I suggest to take a look at DTCoreText.

UICoreTextView contains 2 major components:

* <b>UICoreTextView</b> - UIView based, used to render the string
* <b>HTMLParser</b> - HTML parser which generates an instance of NSAttributedString. There is also a category for NSAttributedString, for easy creation of NSAttributedString objects.

Examples
-

Please also refer to the demo project for a working demo.

#### Basic styling
    m_coreText.attributedString=[NSAttributedString attributedStringWithHTML:@"<span font='Papyrus' size='12' color='rgba(255,0,255,0.5)'>This is a styled string</span>"];

#### Custom Rendering
###### 50x50 Blue circle renderer
    @interface BlueCircle : NSObject<HTMLRenderer>
    @end
    @implementation BlueCircle
    -(CGSize)size
    {
    	return CGSizeMake(50, 50);
    }
    -(void)renderInContext:(CGContextRef)context rect:(CGRect)rect
    {
    	CGContextSetFillColorWithColor(context, [UIColor blueColor].CGColor);
    	CGContextFillEllipseInRect(context, rect);
    }
    @end

###### Using the renderer callback
    NSString* html=@"DIV elements generate custom renderers: <div />";
    m_coreText.attributedString=[NSAttributedString attributedStringWithHTML:html renderer:^id<HTMLRenderer>(NSMutableDictionary* attributes)
    {
    	return [[BlueCircle alloc] init];
    }];

Styling
-

Since UICoreTextView was designed mainly to work with custom renderers - passing attributes from the HTML to the callback should be as simple as possible. For that reason, the syntax is based on plain old HTML tags and not modern CSS. The callback receives an instance of NSMutableAttributes, which contains all available attributes of that HTML node.

The syntax was meant to be as simple as possible and at no point was it designed to follow HTML standards. For that reason, some of the HTML tags/attributes might differ from the original specs (for example, &lt;s&gt; for stroke rather than &lt;stroke&gt;)

### Text
    <span font='ArialMT|Georgia|...' size='16'>Font manipulation, we can change font name and size</font>

    <b>Bold>
    <u style='none|single|thick|double'>Underline</u>
    <i>Italic</i>
    <s width='3' color='rgb(255,0,0)'>Red stroke</s>

    <span align='natural|left|right|center|justified'>Aligned text</span>
    <span direction='rtl|ltr'>RTL or LTR text</span>
    <span wrap='word|break-word|clip|ellipsis-head|ellipsis-tail|ellipsis-middle'>Wrapped text</span>

### Colors
    <span color='#FF0000'>Standard HTML colors</span>
    <span color='rgb(255,0,0)'>RGB color</span>
    <span color='rgba(255,0,0,0.5)'>RGBA color</span>

### Links
By default, all links will render using a blue color and a single underline (which you can override using the <code>color</code> tag and an embedded <code>u</code> tag).
UICoreTextView will try by default to open any link using <code>[[UIApplication sharedApplication] openURL:url]</code>. You can prevent this behaviour by returning YES from <code>-(BOOL)coreTextView:(UICoreTextView*)view openURL:(NSURL*)url</code> delegate.

    <a href='http://www.google.com/'>Google.com</a>
    <a href='tel:+180012345678'>Click to call</a>

### Images
Images can be embedded using the <b>base64:</b> prefix or be loaded from disk. Images will be loaded using <code>[UIImage imageNamed:src]</code> - unless the <b>file://</b> scheme is specified.
For images, you can also use the <code>valign='middle'</code> attribute to center them vertically.

    <img src='base64:iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==' />
    <img width='50' height='50' src='avatar.png' />
    <img src='file://..../house.jpg' valign='middle' />

### Others
    <br>
    <hr height='5' color='#FF0000' />

Custom Renderer
-

Sometimes your app needs to render some content dynamically. One option would be to generate an image and create a new NSAttributedString every time - or you can use a custom renderer.

Custom renderers use a callback, passing a graphic context to draw into. An app can then use it to draw whatever it needs.

To create a custom renderer, simply use a <code>div</code> tag inside your HTML. You can also set custom attributes which will be passed to the renderer factory. Custom attributes allow you to distinguish between different renderers in the same HTML.

To be able to create a custom renderer, you'll need to pass a callback to the HTML parser:

    NSString* html=@"<div type='square' /><div type='circle' />";
    m_coreText.attributedString=[NSAttributedString attributedStringWithHTML:html renderer:^id<HTMLRenderer>(NSMutableDictionary* attributes)
    {
    	if ([attributes[@"type"] isEqualToString:@"circle"])
    	{
    	...
    	}
    	return m_customRenderer;
    }];

A custom renderer can be any object defining the <code>HTMLRenderer</code> protocol:

    @protocol HTMLRenderer<NSObject>
    @required
    @property(nonatomic,readonly) CGSize size;
    @optional
    @property(nonatomic,readonly) CGFloat ascent;
    @property(nonatomic,readonly) CGFloat descent;

    @required
    -(void)renderInContext:(CGContextRef)context rect:(CGRect)rect;
    @end

The only 2 required methods are <code>-(CGSize>size</code> and <code>-(void)renderInContext:(CGContextRef)context rect:(CGRect)rect</code>, so if we want to draw a simple blue circle, our renderer will be similar to the following implementation:

    @interface BlueCircle : NSObject<HTMLRenderer>
    @end
    @implementation BlueCircle
    -(CGSize)size
    {
    	return CGSizeMake(50, 50);	// make our circle 50x50 points
    }
    -(void)renderInContext:(CGContextRef)context rect:(CGRect)rect
    {
    	CGContextSetFillColorWithColor(context, [UIColor blueColor].CGColor);
    	CGContextFillEllipseInRect(context, rect);
    }
    @end

We then use the parser's factory callback to create a new instance of <code>BlueCircle</code>. The new renderer will be retained by the resulting NSAttributedString.

    m_coreText.attributedString=[NSAttributedString attributedStringWithHTML:@"Hello <div /> World" renderer:^id<HTMLRenderer>(NSMutableDictionary* attributes)
    {
    	return [[BlueCircle alloc] init];
    }];

# Setup

Everything is contained in 2 files only: UICoreTextView.mm & UICoreTextView.h.

UICoreTextView uses ARC. If your project does not use ARC, you'll need to set the following flag for UICoreTextView.mm: <code>-fobjc-arc</code> (<a href='http://stackoverflow.com/questions/10523816/how-to-enable-arc-for-a-single-file'>How to enable ARC for a single file</a>)

You'll also need to include <code>libxml2.dylib</code> in your project:

* Link your project against <code>libxml2.dylib</code> and <code>CoreText.framework</code>
* Under your build settings, add the following path under <b>"Header Search Paths"</b>: <code>/usr/include/libxml2</code>

# Credits

UICoreTextView was created by <a href='https://github.com/giladno'>Gilad Novik</a>

Many thanks for Oliver Drobnik and his amazing work with <a href='https://github.com/Cocoanetics/DTCoreText'>DTCoreText</a>.

# License

UICoreTextView is licensed under <a href='http://opensource.org/licenses/zlib-license.php'>zlib</a> license:

    Copyright (c) 2013 Gilad Novik

    This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.

    Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.

    2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.

    3. This notice may not be removed or altered from any source distribution.

You do not have to mention UICoreTextView in your app, but I'll appreciate if you do so anyway (or at least email me to let me know about your new great app :-)  )

# Usage

Use it, fork it, push updates - enjoy it!
