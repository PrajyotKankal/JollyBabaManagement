# 🎨 JollyBaba App - Complete Theme Guide

This document provides a comprehensive breakdown of the **JollyBaba Mobile Repairing System** design theme. Use this guide to replicate the same premium, modern aesthetic in other projects.

---

## 🌈 Color Palette

### Primary Colors

```css
/* Main Accent Blue - Used for buttons, icons, links, highlights */
--accent-blue: #6D5DF6;

/* Secondary Accent Purple */
--accent-purple: #8A8EFF;

/* Additional Purple Variants */
--purple-dark: #7B61FF;
--purple-soft: #7A6FF8;
--purple-light: #9D8BFE;
```

### Background Colors

```css
/* Main App Background - Light blue-tinted white */
--background-primary: #F7F9FF;
--background-secondary: #F8FAFF;

/* Alternative Backgrounds */
--background-light-1: #F9FBFF;  /* Off-white */
--background-light-2: #F3F6FF;  /* Light blue tint */
--background-light-3: #EFF3FF;  /* Faint bluish glow */
```

### Text Colors

```css
/* Primary Text - Dark navy for headers */
--text-primary: #1E2343;
--text-primary-alt: #2A2E45;
--text-primary-dark: #1C2044;
--text-primary-grey: #2F2B43;

/* Secondary Text - Soft grey-blue for body text */
--text-secondary: #5B5F77;
--text-secondary-alt: #61637A;

/* Light/Muted Text - Placeholders and hints */
--text-light: #9CA3AF;
```

### Border & Divider Colors

```css
/* Subtle borders for input fields */
--border-grey: #E3E6EF;
--border-light: #E4E6F1;
```

### Status Colors (for ticket status pills)

```css
/* Pending */
--status-pending: #7A6FF8;

/* Repaired */
--status-repaired: #00C6FF;

/* Delivered */
--status-delivered: #56AB2F;

/* Cancelled */
--status-cancelled: #FF4B2B;
```

### Neutral Colors

```css
/* White surfaces */
--surface-white: #FFFFFF;

/* Light grey for chips/inactive states */
--surface-grey: #F1F3FA;
--surface-grey-dark: #F5F6FA;
```

---

## 🎨 Gradients

### Main App Gradient (Blue to Purple)
Used for buttons, highlights, headers, and accent elements.

```css
background: linear-gradient(135deg, #7C83FD 0%, #96A5FF 50%, #C9D6FF 100%);
/* Soft royal blue → Light periwinkle → Pale lavender */
```

**Flutter/Dart:**
```dart
gradient: LinearGradient(
  colors: [
    Color(0xFF7C83FD),  // soft royal blue
    Color(0xFF96A5FF),  // light periwinkle
    Color(0xFFC9D6FF),  // pale lavender
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

### Background Gradient (Soft White-Blue)
Used for full-screen backgrounds.

```css
background: linear-gradient(180deg, #F9FBFF 0%, #F3F6FF 50%, #EFF3FF 100%);
/* Off-white → Light blue tint → Faint bluish glow */
```

**Flutter/Dart:**
```dart
gradient: LinearGradient(
  colors: [
    Color(0xFFF9FBFF),  // off-white
    Color(0xFFF3F6FF),  // light blue tint
    Color(0xFFEFF3FF),  // faint bluish glow
  ],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
)
```

### Card Gradient (Elevated White Surfaces)

```css
background: linear-gradient(135deg, #FFFFFF 0%, #F3F6FF 100%);
```

**Flutter/Dart:**
```dart
gradient: LinearGradient(
  colors: [
    Color(0xFFFFFFFF),
    Color(0xFFF3F6FF),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

### Button/FAB Gradient (Purple Focus)

```css
background: linear-gradient(135deg, #7B61FF 0%, #9D8BFE 100%);
```

**Flutter/Dart:**
```dart
gradient: LinearGradient(
  colors: [
    Color(0xFF7B61FF),
    Color(0xFF9D8BFE)
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

### Splash Screen Gradients

**Main Background:**
```css
background: linear-gradient(135deg, 
  #EEF1FF 0%, 
  #DCE3FF 35%, 
  #F8F9FF 65%, 
  #E9ECFF 100%
);
```

**Logo Circle:**
```css
background: linear-gradient(135deg, #7A6DF6 0%, #8A8EFF 100%);
```

---

## 🔤 Typography

### Font Family
**Google Fonts - Poppins** is used throughout the entire application.

```css
font-family: 'Poppins', sans-serif;
```

**Flutter/Dart:**
```dart
import 'package:google_fonts/google_fonts.dart';

// App-wide theme
textTheme: GoogleFonts.poppinsTextTheme()

// Individual usage
style: GoogleFonts.poppins(
  fontSize: 16,
  fontWeight: FontWeight.w600,
)
```

### Font Weights

```css
--font-light: 300;
--font-regular: 400;
--font-medium: 500;
--font-semibold: 600;
--font-bold: 700;
--font-extrabold: 800;
```

### Font Sizes (Mobile)

```css
/* Headers */
--text-h1: 33px;        /* App name on splash */
--text-h2: 22px;        /* Login title */
--text-h3: 18-20px;     /* Page titles */
--text-h4: 15-16px;     /* Section headers */

/* Body Text */
--text-body: 13-14px;   /* Standard body text */
--text-small: 11-12px;  /* Subtitles, meta info */
--text-tiny: 10px;      /* Footer, labels */
```

### Letter Spacing

```css
--spacing-tight: 0.2px;   /* Status pills */
--spacing-normal: 0.4px;  /* Headings */
--spacing-wide: 1.2px;    /* App title on splash */
```

---

## 💎 Shadows & Elevation

### Soft Shadow (Cards & Buttons)

```css
box-shadow: 0px 8px 15px rgba(96, 125, 139, 0.1);
```

**Flutter/Dart:**
```dart
BoxShadow(
  color: Colors.blueGrey.withOpacity(0.1),
  blurRadius: 15,
  offset: const Offset(0, 8),
)
```

### Card Shadow (Ticket Cards)

```css
box-shadow: 0px 6px 10px rgba(0, 0, 0, 0.04);
```

**Flutter/Dart:**
```dart
BoxShadow(
  color: Colors.black.withValues(alpha: 0.04),
  blurRadius: 10,
  offset: const Offset(0, 6),
)
```

### Navigation Bar Shadow

```css
box-shadow: 0px 4px 12px rgba(0, 0, 0, 0.05);
```

**Flutter/Dart:**
```dart
BoxShadow(
  color: Colors.black.withValues(alpha: 0.05),
  blurRadius: 12,
  offset: const Offset(0, 4),
)
```

### FAB Glow (Animated with breathing effect)

```css
/* Breathing glow animation */
box-shadow: 0px 8px 20-30px rgba(123, 97, 255, 0.2-0.45);
/* Blur and spread radius animate between 20-30 */
```

**Flutter/Dart:**
```dart
BoxShadow(
  color: const Color(0xFF7B61FF).withValues(alpha: 0.2 + glow * 0.25),
  blurRadius: 20 + glow * 10,
  spreadRadius: 1 + glow * 1.5,
  offset: const Offset(0, 8),
)
```

### Logo Glow (Splash Screen)

```css
box-shadow: 0px 0px 30px 8px rgba(124, 116, 245, 0.45);
```

---

## 🎯 Border Radius

### Standard Radii

```css
--radius-small: 10px;     /* Input fields, small buttons */
--radius-medium: 12-14px; /* Cards, search bars */
--radius-large: 20-22px;  /* Chips, large cards */
--radius-xlarge: 36px;    /* Navigation bar (pill shape) */
--radius-circle: 50%;     /* FAB, avatars, dots */
```

---

## ✨ Animations & Effects

### Transition Durations

```css
--duration-fast: 220ms;      /* Chip selection, button hover */
--duration-normal: 300-400ms;/* Page transitions, modals */
--duration-slow: 900ms;      /* Fade-in transitions */
--duration-breathe: 1500-3000ms; /* Breathing glow effects */
```

### Easing Curves

```css
--ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
--ease-out: cubic-bezier(0, 0, 0.2, 1);
--ease-out-back: cubic-bezier(0.34, 1.56, 0.64, 1); /* Bounce effect */
```

**Flutter/Dart:**
```dart
Curves.easeInOut
Curves.easeOut
Curves.easeOutBack
Curves.easeOutCubic
Curves.easeInCubic
```

### Common Animations

#### Fade In
```dart
.animate()
  .fadeIn(duration: 300.ms)
```

#### Slide In from Bottom
```dart
.animate()
  .slideY(begin: 0.14, end: 0, curve: Curves.easeOut)
```

#### Scale Pop-In
```dart
.animate()
  .scaleXY(begin: 0.7, end: 1.0, curve: Curves.easeOutBack)
```

#### Shimmer Effect (Loading)
```dart
.animate(onPlay: (controller) => controller.repeat(reverse: true))
  .shimmer(duration: const Duration(milliseconds: 3000))
```

#### Breathing Glow
```dart
AnimationController(
  duration: const Duration(seconds: 3),
)..repeat(reverse: true)

Tween<double>(begin: 0.10, end: 0.40)
  .animate(CurvedAnimation(
    parent: controller,
    curve: Curves.easeInOut
  ))
```

---

## 🧩 UI Components

### Input Fields

```css
/* Style */
background: #FFFFFF or #F5F6FA;
border: 1px solid #E3E6EF;
border-radius: 10px;
padding: 12px vertical, 12px horizontal;

/* Focus State */
border-color: #6D5DF6;
```

### Buttons (Primary)

```css
background: #6D5DF6;
color: #FFFFFF;
border-radius: 10px;
padding: 10px 12px;
font-weight: 600;
font-size: 14px;
box-shadow: 0 8px 15px rgba(96, 125, 139, 0.1);
```

### Status Pills

```css
/* Container */
background: rgba(status-color, 0.10);
border: 1px solid rgba(status-color, 0.15);
border-radius: 10px;
padding: 6px 10-14px;

/* Text */
color: rgba(status-color, 0.9);
font-weight: 600;
font-size: 11-12.5px;
letter-spacing: 0.2px;
```

### Filter Chips

```css
/* Inactive */
background: #F1F3FA;
color: #000000DE;

/* Active */
background: #6D5DF6;
color: #FFFFFF;

/* Common */
border-radius: 20px;
padding: 6px 12-18px;
font-weight: 600;
font-size: 13px;
transition: 220ms;
```

### Cards

```css
background: #FFFFFF;
border-radius: 14px;
padding: 8-12px;
box-shadow: 0px 6px 10px rgba(0, 0, 0, 0.04);
```

### Navigation Bar (Bottom)

```css
/* Pill Container */
background: rgba(255, 255, 255, 0.92);
backdrop-filter: blur(10px);
border-radius: 36px;
height: 64px;
box-shadow: 0px 4px 12px rgba(0, 0, 0, 0.05);

/* Icons */
size: 24px;
active-color: #7B61FF (left) or #00C6FF (right);
inactive-color: rgba(0, 0, 0, 0.40);
```

### Floating Action Button (FAB)

```css
/* Container */
width: 72px;
height: 72px;
background: linear-gradient(135deg, #7B61FF, #9D8BFE);
border-radius: 50%;
box-shadow: 0px 8px 20px rgba(123, 97, 255, 0.2);
/* Animated glow */

/* Icon */
color: #FFFFFF;
size: 34px;
```

---

## 🎭 Special Effects

### Glassmorphism

```css
background: rgba(255, 255, 255, 0.92);
backdrop-filter: blur(10px);
```

**Flutter/Dart:**
```dart
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
  child: Container(
    color: Colors.white.withValues(alpha: 0.92),
  )
)
```

### Animated Border (Login Screen)

A rotating gradient border that creates a "snake" effect:

```dart
SweepGradient(
  transform: GradientRotation(2 * pi * animationProgress),
  colors: [
    Color(0x00B89CFF),                           // transparent
    Color(0xFF5A45E0).withValues(alpha: 0.95),   // darker purple
    Color(0xFF7C63FF).withValues(alpha: 0.8),    // lighter purple
    Color(0x00B89CFF),                           // transparent
  ],
  stops: [0.0, 0.4, 0.6, 1.0],
)
```

### Highlight Gradient (Nav Bar)

A subtle top-to-bottom highlight on navigation bar:

```dart
LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Colors.white.withValues(alpha: 0.06),
    Colors.white.withValues(alpha: 0.0)
  ],
)
```

---

## 📱 Responsive Design

### Breakpoints

```css
/* Mobile */
--breakpoint-mobile: < 600px;

/* Tablet */
--breakpoint-tablet: 600px - 1024px;

/* Desktop */
--breakpoint-desktop: > 1024px;
```

### Scaling Patterns

```dart
// Font scaling
final scale = ResponsiveHelper.getResponsiveFontSize(context, 14) / 14;

// Padding scaling (horizontal)
final horizontalPadding = deviceType == DeviceType.mobile
  ? 16.0
  : deviceType == DeviceType.tablet
    ? 24.0
    : width > 1400
      ? width * 0.12
      : width * 0.05;
```

---

## 🎨 Design Principles

### 1. **Premium & Modern**
- Use soft blues and purples for a premium feel
- Avoid harsh colors (use pastel/soft variants)
- Generous white space and subtle shadows

### 2. **Glassmorphism**
- Frosted glass effects with backdrop blur
- Semi-transparent backgrounds (0.92 alpha)
- Layered depth with blur filters

### 3. **Smooth Animations**
- Everything has a transition (220-400ms)
- Use breathing/pulsing effects for CTAs
- Stagger animations for lists (80ms delay per item)

### 4. **Gradient-First**
- Prefer gradients over solid colors
- Use gradients for backgrounds, buttons, and accents
- Keep gradients subtle (2-3 color stops max)

### 5. **Rounded & Soft**
- No sharp corners (minimum 10px radius)
- Pills and circles for interactive elements
- Generous padding for touchable areas

### 6. **Consistent Shadows**
- Use soft, elevated shadows (not harsh)
- Shadow opacity: 0.04 - 0.1
- Shadow color: black or blueGrey

---

## 🛠️ Implementation Tips

### For Web (CSS/HTML/JavaScript)

1. **Import Poppins font:**
```html
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
```

2. **Use CSS Variables:**
```css
:root {
  --accent-blue: #6D5DF6;
  --background: #F7F9FF;
  --text-primary: #1E2343;
  /* ... rest of colors */
}
```

3. **Add backdrop blur for glassmorphism:**
```css
.glass {
  background: rgba(255, 255, 255, 0.92);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
}
```

### For React/Next.js

Use CSS modules or styled-components with the theme values.

### For Flutter

Import the theme file and use throughout the app:

```dart
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_colors.dart';

ThemeData(
  useMaterial3: true,
  textTheme: GoogleFonts.poppinsTextTheme(),
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.light,
  ),
)
```

---

## 📸 Visual Reference

The app features:
- **Splash Screen**: Gradient background with breathing glow logo
- **Login Screen**: Animated rotating border with glassmorphic card
- **Dashboard**: White cards on light blue background, purple accent chips
- **Navigation**: Frosted glass pill-shaped bar with circular FAB
- **Cards**: White surface with subtle shadows and rounded corners

---

## 🎯 Quick Color Reference Cheat Sheet

| Element | Color/Gradient |
|---------|----------------|
| Primary Button | `#6D5DF6` |
| FAB | `linear-gradient(135deg, #7B61FF, #9D8BFE)` |
| Background | `#F7F9FF` |
| Card | `#FFFFFF` |
| Text Primary | `#1E2343` |
| Text Secondary | `#5B5F77` |
| Border | `#E3E6EF` |
| Status Pending | `#7A6FF8` |
| Status Repaired | `#00C6FF` |
| Status Delivered | `#56AB2F` |
| Inactive Chip | `#F1F3FA` |

---

This theme creates a **premium, modern, and calming** user experience with its soft blue-purple palette, smooth animations, and glassmorphic elements. Perfect for professional SaaS, mobile apps, dashboards, and management systems!
