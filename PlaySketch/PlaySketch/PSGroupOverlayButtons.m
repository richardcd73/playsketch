/*
 
 --------------
 Copyright 2012 Singapore Management University
 
 This Source Code Form is subject to the terms of the
 Mozilla Public License, v. 2.0. If a copy of the MPL was
 not distributed with this file, You can obtain one at
 http://mozilla.org/MPL/2.0/.
 --------------
 
 */

#import "PSGroupOverlayButtons.h"
#import "PSDrawingGroup.h"
#import "PSGraphicConstants.h"

@implementation PSGroupOverlayButtons

- (void)configureForSelectionCount:(int)count isLeafObject:(BOOL)isLeaf isVisible:(BOOL)isVisible
{
	// Decide what buttons to show
	self.recordingButton.hidden = NO;
	self.createGroupButton.hidden = (count == 1);
	self.disbandGroupButton.hidden = (count > 1) || isLeaf;
	self.visibilityOffButton.hidden = !isVisible;
	self.visibilityOnButton.hidden = isVisible;
	self.deleteGroupButton.hidden = NO;
	
	//Lay them out dynamically
	NSArray* allButtons = [NSArray arrayWithObjects:self.recordingButton,
													self.createGroupButton,
													self.disbandGroupButton,
													self.visibilityOnButton,
													self.visibilityOffButton,
													self.deleteGroupButton,
													nil];
	CGFloat yOffset = 0;
	for (UIButton* b in allButtons)
	{
		if (b.hidden) continue;
		CGRect f = b.frame;
		f.origin.y = yOffset;
		b.frame = f;
		yOffset += f.size.height;
	}
}

- (void)startRecordingMode
{
	self.recordingButton.selected = YES;
	
}

- (void)stopRecordingMode
{
	self.recordingButton.selected = NO;
}

- (void)setRecordPulsing:(BOOL)recordPulsing
{
	UIColor* color1 = RECORD_BUTTON_PULSE_UP_UICOLOR;
	UIColor* color2 = RECORD_BUTTON_PULSE_DOWN_UICOLOR;
	
	if (recordPulsing && !_recordPulsing)
	{
		// Start pulsing
		self.recordingButton.backgroundColor = color1;
		[UIView animateWithDuration:1.0
							  delay:0.0
							options:UIViewAnimationOptionRepeat |
									UIViewAnimationOptionAutoreverse |
									UIViewAnimationOptionCurveEaseInOut
						 animations: ^{ self.recordingButton.backgroundColor = color2; }
						 completion:nil];

	}
	else if (!recordPulsing && _recordPulsing)
	{
		// Stop pulsing and go back to the original color
		[UIView animateWithDuration:0.3
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseInOut
						 animations: ^{ self.recordingButton.backgroundColor = color1; }
						 completion:nil];
	}

	_recordPulsing = recordPulsing;
}

@end
