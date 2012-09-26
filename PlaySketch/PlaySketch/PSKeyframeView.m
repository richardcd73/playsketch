/*
 
 --------------
 Copyright 2012 Singapore Management University
 
 This Source Code Form is subject to the terms of the
 Mozilla Public License, v. 2.0. If a copy of the MPL was
 not distributed with this file, You can obtain one at
 http://mozilla.org/MPL/2.0/.
 --------------
 
 */

#import "PSKeyframeView.h"
#import "PSDataModel.h"
#import <QuartzCore/QuartzCore.h>
#import "PSAnimationRenderingController.h" //for the pen colours to use


/* Private helper class for doing the drawing */
@interface PSKeyframeView ()
//@property(nonatomic,retain)CALayer* allKeyframeLayer;
//@property(nonatomic,retain)CALayer* selectedKeyframeLayer;
@end

@implementation PSKeyframeView


- (void)awakeFromNib
{
}

- (void)drawRect:(CGRect)rect
{
	NSLog(@"drawing");
	
	// Collect all of the x-values for keyframes in a set to avoid duplicates
	NSMutableSet* xOffsetsSelected = [NSMutableSet set];
	NSMutableSet* xOffsetsUnselected = [NSMutableSet set];
	
	[self.rootGroup applyToAllSubTrees:^(PSDrawingGroup *g, BOOL subtreeSelected) {
		for(int i = 0; i < g.positionCount; i++)
		{
			SRTPosition p = g.positions[i];
			if(SRTKeyframeIsAny(p.keyframeType))
			{
				int xVal = (int)((p.timeStamp/10.0) * self.frame.size.width);
				if(subtreeSelected)
					[xOffsetsSelected addObject:[NSNumber numberWithInt:xVal]];
				else
					[xOffsetsUnselected addObject:[NSNumber numberWithInt:xVal]];
			}
		}
	}];
	
	
	// Draw them all
	[self drawKeyframes:xOffsetsUnselected withColor:[UIColor grayColor]];
	[self drawKeyframes:xOffsetsSelected withColor:SELECTION_PEN_COLOR];
	
}

- (void)drawKeyframes:(NSSet*)xOffsets withColor:(UIColor*)color
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(context, color.CGColor);
	CGRect r = CGRectMake(0, 0, 10, self.frame.size.height);
	for (NSNumber* x in xOffsets)
	{
		r.origin.x = x.intValue - r.size.width/2.0;
		CGContextFillRect (context, r);
	}
}

- (void)refreshAll
{
	[self setNeedsDisplay];
}

@end
