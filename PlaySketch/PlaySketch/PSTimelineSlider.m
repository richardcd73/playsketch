/*
 
 --------------
 Copyright 2012 Singapore Management University
 
 This Source Code Form is subject to the terms of the
 Mozilla Public License, v. 2.0. If a copy of the MPL was
 not distributed with this file, You can obtain one at
 http://mozilla.org/MPL/2.0/.
 --------------
 
 */


#import "PSTimelineSlider.h"
#import "PSTimelineLabelView.h"

@interface PSTimelineSlider ()
@property(nonatomic,retain)NSTimer* timer;
@end


@implementation PSTimelineSlider

- (void)awakeFromNib
{
	[self setThumbImage:[UIImage imageNamed:@"slider"] forState:UIControlStateNormal];
	[self.labelView setLabelsForTimelineSlider:self];
}

- (void)setPlaying:(BOOL)playing
{
	if (playing && !_playing)
	{
		//create a new timer to update our animation
		self.timer = [NSTimer scheduledTimerWithTimeInterval:1/30.0
												  target:self
												selector:@selector(timerUpdate)
												userInfo:nil
												 repeats:YES];
	
		[self.playButton setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
	}
	else if (!playing && _playing)
	{
		[self.timer invalidate];
		self.timer = nil;
		
		[self.playButton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
	}
	
	_playing = playing;
}

- (void)timerUpdate
{
	self.value += self.timer.timeInterval;
	
	if(self.value >= self.maximumValue)
		self.playing = NO;
}

- (float)xOffsetForTime:(float)time
{
	float imgWidth = self.currentThumbImage.size.width;
	float pcnt = (time/self.maximumValue);
	return imgWidth/2.0 + pcnt*(self.frame.size.width - imgWidth);
}

- (BOOL)nearEndOfTimeline:(float)time
{
	return (self.maximumValue - time) < 2.0;
}


- (void)expandTimeline
{
	self.maximumValue += 5.0;
}

- (void)setMaximumValue:(float)maximumValue
{
	[super setMaximumValue:maximumValue];
	[self.labelView setLabelsForTimelineSlider:self];
	
}



@end
