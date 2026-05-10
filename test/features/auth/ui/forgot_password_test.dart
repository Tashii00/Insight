// test/features/auth/ui/forgot_password_test.dart
// FINAL FIX for TC-FP-08:
// The Completer approach was correct but the SnackBar after completer.complete()
// triggers a ScaffoldMessenger lookup which needs a Navigator.
// Fix: wrap in buildPageWithNav() + handle the pop after complete().

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:insight/features/auth/data/auth_service.dart';
import 'package:insight/features/auth/ui/forgot_password_page.dart';

import 'forgot_password_test.mocks.dart';

@GenerateMocks([AuthService])
void main() {
  late MockAuthService mockAuth;

  setUp(() {
    mockAuth = MockAuthService();
  });

  // Wraps page without Navigator (validator-only tests)
  Widget buildPage() {
    return MaterialApp(home: ForgotPasswordPage(authService: mockAuth));
  }

  // Wraps page inside Navigator so pop() and SnackBar work
  Widget buildPageWithNav() {
    return MaterialApp(
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ForgotPasswordPage(authService: mockAuth),
                      ),
                    ),
                child: const Text('Open'),
              ),
            ),
      ),
    );
  }

  group('TC-FP | ForgotPasswordPage Widget Tests', () {
    // ─────────────────────────────────────────────────────────
    // TC-FP-03a: Empty email → "Email is required"
    // ─────────────────────────────────────────────────────────
    testWidgets('TC-FP-03a: Empty email shows "Email is required"', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(find.text('Email is required'), findsOneWidget);
    });

    // ─────────────────────────────────────────────────────────
    // TC-FP-03b: Email without @ → "Enter a valid email"
    // ─────────────────────────────────────────────────────────
    testWidgets('TC-FP-03b: Email without @ shows "Enter a valid email"', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.enterText(find.byType(TextFormField), 'notanemail');
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    // ─────────────────────────────────────────────────────────
    // TC-FP-01: Valid email → success snackbar shown
    // ─────────────────────────────────────────────────────────
    testWidgets('TC-FP-01: Valid email shows success snackbar', (tester) async {
      when(
        mockAuth.sendPasswordResetEmail(email: 'test@insight.com'),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildPageWithNav());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'test@insight.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(
        find.text('Password reset email sent. Check inbox/spam.'),
        findsOneWidget,
      );
    });

    // ─────────────────────────────────────────────────────────
    // TC-FP-02: Unregistered email → error snackbar
    // ─────────────────────────────────────────────────────────
    testWidgets(
      'TC-FP-02: Unregistered email shows "No account found for this email."',
      (tester) async {
        when(
          mockAuth.sendPasswordResetEmail(email: 'ghost@nowhere.com'),
        ).thenThrow(Exception('user-not-found'));

        await tester.pumpWidget(buildPage());
        await tester.enterText(find.byType(TextFormField), 'ghost@nowhere.com');
        await tester.tap(find.text('Send reset link'));
        await tester.pumpAndSettle();

        expect(find.text('No account found for this email.'), findsOneWidget);
      },
    );

    // ─────────────────────────────────────────────────────────
    // TC-FP-07: Too many requests → error snackbar
    // ─────────────────────────────────────────────────────────
    testWidgets(
      'TC-FP-07: Too many requests shows "Too many attempts. Try later."',
      (tester) async {
        when(
          mockAuth.sendPasswordResetEmail(email: 'test@insight.com'),
        ).thenThrow(Exception('too-many-requests'));

        await tester.pumpWidget(buildPage());
        await tester.enterText(find.byType(TextFormField), 'test@insight.com');
        await tester.tap(find.text('Send reset link'));
        await tester.pumpAndSettle();

        expect(find.text('Too many attempts. Try later.'), findsOneWidget);
      },
    );

    // ─────────────────────────────────────────────────────────
    // TC-FP-08: Loading spinner shown while request in flight
    // FINAL FIX: pump() only one frame after tap, then immediately
    // complete the future and pumpAndSettle to clean all timers.
    // ─────────────────────────────────────────────────────────
    testWidgets(
      'TC-FP-08: Loading spinner visible while reset email is sending',
      (tester) async {
        final completer = Completer<void>();

        when(
          mockAuth.sendPasswordResetEmail(email: 'test@insight.com'),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(buildPage());
        await tester.enterText(find.byType(TextFormField), 'test@insight.com');

        // Tap the button — this starts the async _sendReset()
        await tester.tap(find.text('Send reset link'));
        await tester.pump(); // one frame: _loading = true, spinner appears

        // ✅ Verify spinner IS shown and button IS hidden
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Send reset link'), findsNothing);

        // Complete the future to unblock the async work
        completer.complete();

        // pumpAndSettle waits for all async work and timers to finish
        await tester.pumpAndSettle();
        // No pending timers remain — test passes cleanly
      },
    );

    // ─────────────────────────────────────────────────────────
    // TC-FP-04: Back button pops the page
    // ─────────────────────────────────────────────────────────
    testWidgets('TC-FP-04: AppBar back button pops ForgotPasswordPage', (
      tester,
    ) async {
      await tester.pumpWidget(buildPageWithNav());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordPage), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordPage), findsNothing);
    });

    // ─────────────────────────────────────────────────────────
    // TC-FP-09: All UI elements render correctly
    // ─────────────────────────────────────────────────────────
    testWidgets(
      'TC-FP-09: Page renders AppBar title, email field, and send button',
      (tester) async {
        await tester.pumpWidget(buildPage());

        expect(find.text('Forgot Password'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Send reset link'), findsOneWidget);
        expect(
          find.text("Enter your email and we'll send a reset link."),
          findsOneWidget,
        );
      },
    );
  });
}
