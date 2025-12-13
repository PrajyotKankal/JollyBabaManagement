# Responsive Design - Quick Reference Guide

## Using ResponsiveHelper in Your Code

### Basic Setup
```dart
import '../utils/responsive_helper.dart';

// In your build method
final deviceType = ResponsiveHelper.getDeviceType(context);
final isPortrait = ResponsiveHelper.isPortrait(context);
```

### Device Type Checking
```dart
if (deviceType == DeviceType.mobile) {
  // Mobile-specific code
} else if (deviceType == DeviceType.tablet) {
  // Tablet-specific code
} else {
  // Desktop-specific code
}
```

### Responsive Utilities

#### Padding
```dart
final padding = ResponsiveHelper.getResponsivePadding(context);
// Returns: EdgeInsets.symmetric(horizontal: 16, vertical: 12) on mobile
//          EdgeInsets.symmetric(horizontal: 24, vertical: 16) on tablet
//          EdgeInsets.symmetric(horizontal: 32, vertical: 20) on desktop
```

#### Font Size
```dart
final fontSize = ResponsiveHelper.getResponsiveFontSize(context, 14);
// Scales 14px base size to device-appropriate size
```

#### Grid Columns
```dart
final columns = ResponsiveHelper.getGridColumns(context);
// Returns: 1 on mobile, 2 on tablet, 3 on desktop
```

#### Card Spacing
```dart
final spacing = ResponsiveHelper.getCardSpacing(context);
// Returns: 12 on mobile, 16 on tablet, 20 on desktop
```

#### Border Radius
```dart
final radius = ResponsiveHelper.getResponsiveBorderRadius(context);
// Returns: 12 on mobile, 14 on tablet, 16 on desktop
```

#### List Item Height
```dart
final height = ResponsiveHelper.getListItemHeight(context);
// Returns: 100 on mobile, 110 on tablet, 120 on desktop
```

#### Max Content Width
```dart
final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
// Returns appropriate max width for large screens
```

## Common Patterns

### Responsive Column/Row Layout
```dart
deviceType == DeviceType.mobile
    ? Column(
        children: [
          // Stacked items
        ],
      )
    : Row(
        children: [
          // Side-by-side items
        ],
      )
```

### Responsive Font Size
```dart
Text(
  'Hello',
  style: GoogleFonts.poppins(
    fontSize: deviceType == DeviceType.mobile ? 14 : 16,
  ),
)
```

### Responsive Padding
```dart
Padding(
  padding: EdgeInsets.all(
    deviceType == DeviceType.mobile ? 12 : 16,
  ),
  child: // ...
)
```

### Responsive Grid
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: ResponsiveHelper.getGridColumns(context),
  ),
  // ...
)
```

### Text Overflow Handling
```dart
Text(
  'Long text here',
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
)
```

## Breakpoints Reference

```
Mobile:  < 600px
Tablet:  600px - 1199px
Desktop: ≥ 1200px
```

## Padding Values by Device

```
Mobile:  14-16px
Tablet:  18-24px
Desktop: 24-32px
```

## Font Scale Factors

```
Mobile:  0.8x - 1.0x
Tablet:  1.0x - 1.1x
Desktop: 1.1x - 1.3x
```

## Testing Shortcuts

### Test Mobile (375px)
```bash
flutter run -d emulator-5554 --profile
# Then use DevTools to set viewport to 375x667
```

### Test Tablet (768px)
```bash
# Use iPad Air emulator or set viewport to 768x1024
```

### Test Desktop (1920px)
```bash
flutter run -d chrome --web-port 8080
# Then resize browser to 1920x1080
```

## Common Issues & Solutions

### Issue: Layout breaks on rotation
**Solution**: Use `ResponsiveHelper.isPortrait()` to detect and adjust

### Issue: Text overflows
**Solution**: Add `maxLines` and `overflow: TextOverflow.ellipsis`

### Issue: Buttons too small on mobile
**Solution**: Ensure minimum 44px height

### Issue: Excessive padding on desktop
**Solution**: Use responsive padding helpers

### Issue: Content cut off at bottom
**Solution**: Add `bottomReserve` padding for nav/FAB

## Checklist for New Screens

- [ ] Import `responsive_helper.dart`
- [ ] Get `deviceType` in build method
- [ ] Use responsive padding
- [ ] Adapt layouts based on device type
- [ ] Handle text overflow
- [ ] Test on mobile, tablet, desktop
- [ ] Test portrait and landscape
- [ ] Verify touch targets (min 44px)
- [ ] Check text readability
- [ ] Verify no console errors

## Performance Tips

1. **Avoid excessive rebuilds**: Cache device type if used multiple times
2. **Use const constructors**: Where possible for better performance
3. **Lazy load**: Heavy widgets on demand
4. **Optimize animations**: Keep frame rate smooth
5. **Profile on real devices**: Emulators may not reflect actual performance

## Accessibility Checklist

- [ ] Text contrast meets WCAG AA standards
- [ ] Font sizes readable without zoom (min 12px)
- [ ] Touch targets large enough (min 44px)
- [ ] Color not sole means of information
- [ ] Semantic structure maintained
- [ ] Screen reader compatible

## Resources

- **Responsive Design Summary**: See `RESPONSIVE_DESIGN_SUMMARY.md`
- **Testing Guide**: See `RESPONSIVE_TESTING_GUIDE.md`
- **Implementation Details**: See `IMPLEMENTATION_COMPLETE.md`
- **Helper Source**: `lib/utils/responsive_helper.dart`

## Quick Examples

### Example 1: Responsive Card
```dart
Card(
  margin: EdgeInsets.symmetric(
    vertical: deviceType == DeviceType.mobile ? 6 : 8,
  ),
  child: Padding(
    padding: EdgeInsets.all(
      deviceType == DeviceType.mobile ? 12 : 16,
    ),
    child: // ...
  ),
)
```

### Example 2: Responsive List
```dart
ListView.builder(
  padding: EdgeInsets.all(
    deviceType == DeviceType.mobile ? 12 : 16,
  ),
  itemBuilder: (context, index) {
    return _buildItem(index, deviceType);
  },
)
```

### Example 3: Responsive Grid
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: ResponsiveHelper.getGridColumns(context),
    mainAxisSpacing: ResponsiveHelper.getCardSpacing(context),
    crossAxisSpacing: ResponsiveHelper.getCardSpacing(context),
  ),
  itemBuilder: (context, index) {
    return _buildGridItem(index);
  },
)
```

---

**Last Updated**: November 22, 2025
**Version**: 1.0
