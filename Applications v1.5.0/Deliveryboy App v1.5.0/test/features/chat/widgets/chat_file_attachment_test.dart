// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:open_file_platform_interface/open_file_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/chat/cubit/chat_cubit.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/widgets/chat_file_attachment.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

class MockChatCubit extends MockCubit<ChatState> implements ChatCubit {}

/// Records every path passed to `OpenFile.open` instead of hitting a real
/// platform channel, which throws `MissingPluginException` under `flutter
/// test`.
class FakeOpenFilePlatform extends OpenFilePlatform {
  final List<String?> opened = [];

  @override
  Future<OpenResult> open(
    String? filePath, {
    String? type,
    bool isIOSAppOpen = false,
    String linuxDesktopName = 'xdg',
    bool linuxUseGio = false,
    bool linuxByProcess = false,
  }) async {
    opened.add(filePath);
    return OpenResult(type: ResultType.done, message: 'done');
  }
}

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  FakePathProviderPlatform(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  late Directory tempDir;
  late FakeOpenFilePlatform fakeOpenFile;
  late MockChatCubit mockChatCubit;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('chat_file_attachment_test_');
    fakeOpenFile = FakeOpenFilePlatform();
    OpenFilePlatform.platform = fakeOpenFile;
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
    mockChatCubit = MockChatCubit();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpAttachment(
    WidgetTester tester,
    ChatAttachment attachment, {
    bool isMe = false,
  }) async {
    await tester.pumpWidget(
      pumpTestWidget(
        BlocProvider<ChatCubit>.value(
          value: mockChatCubit,
          child: ChatFileAttachment(attachment: attachment, isMe: isMe),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the file name and a document icon for a non-video attachment', (tester) async {
    printTestDivider('ChatFileAttachment shows the file name and a document icon for a non-video attachment');
    await pumpAttachment(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/invoice.pdf',
        fileName: 'invoice.pdf',
        type: AttachmentType.file,
      ),
    );

    printTestLog('name → expected: "invoice.pdf" visible');
    expect(find.text('invoice.pdf'), findsOneWidget);
    final icon = tester.widget<AppSvgIcon>(find.byType(AppSvgIcon));
    printTestLog(
      'icon → expected: ${AssetsConstants.fileIcon}, actual: ${icon.path}',
    );
    expect(icon.path, AssetsConstants.fileIcon);
  });

  testWidgets('shows the play-circle icon for a video attachment', (tester) async {
    printTestDivider('ChatFileAttachment shows the play-circle icon for a video attachment');
    await pumpAttachment(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/delivery.mp4',
        fileName: 'delivery.mp4',
        type: AttachmentType.video,
      ),
    );

    final icon = tester.widget<AppSvgIcon>(find.byType(AppSvgIcon));
    printTestLog(
      'icon → expected: ${AssetsConstants.playCircleIcon}, actual: ${icon.path}',
    );
    expect(icon.path, AssetsConstants.playCircleIcon);
  });

  testWidgets('falls back to the generic file label when fileName is null', (tester) async {
    printTestDivider('ChatFileAttachment falls back to the generic file label when fileName is null');
    await pumpAttachment(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/blob',
        type: AttachmentType.file,
      ),
    );

    printTestLog('label → expected: "${LanguageLabelKeys.attachmentFile}" visible');
    expect(find.text(LanguageLabelKeys.attachmentFile), findsOneWidget);
  });

  testWidgets('tapping a local file opens it directly without touching the cubit', (tester) async {
    printTestDivider('ChatFileAttachment tapping a local file opens it directly without touching the cubit');
    final file = File('${tempDir.path}/invoice.pdf')..writeAsStringSync('x');

    await pumpAttachment(
      tester,
      ChatAttachment(localPath: file.path, fileName: 'invoice.pdf', type: AttachmentType.file),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    printTestLog('opened path → expected: "${file.path}", actual: "${fakeOpenFile.opened}"');
    expect(fakeOpenFile.opened, [file.path]);
    verifyNever(
      () => mockChatCubit.downloadAttachment(any(), any()),
    );
  });

  testWidgets('tapping a remote-only file downloads through the cubit then opens it, showing a spinner meanwhile', (tester) async {
    printTestDivider('ChatFileAttachment tapping a remote-only file downloads through the cubit then opens it, showing a spinner meanwhile');
    final completer = Completer<void>();
    when(
      () => mockChatCubit.downloadAttachment(any(), any()),
    ).thenAnswer((_) => completer.future);

    await pumpAttachment(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/invoice.pdf',
        fileName: 'invoice.pdf',
        type: AttachmentType.file,
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    printTestLog(
      'spinner while downloading → expected: 1, actual: ${find.byType(ShimmerInline).evaluate().length}',
    );
    expect(find.byType(ShimmerInline), findsOneWidget);

    final expectedPath = '${tempDir.path}/invoice.pdf';
    verify(
      () => mockChatCubit.downloadAttachment('https://cdn.test/invoice.pdf', expectedPath),
    ).called(1);

    completer.complete();
    await tester.pump();
    await tester.pump();

    printTestLog('opened path → expected: "$expectedPath", actual: "${fakeOpenFile.opened}"');
    expect(fakeOpenFile.opened, [expectedPath]);
    printTestLog(
      'spinner after completion → expected: gone, actual: ${find.byType(ShimmerInline).evaluate().length}',
    );
    expect(find.byType(ShimmerInline), findsNothing);
  });

  testWidgets('a download failure shows the could-not-download snackbar and resets the spinner', (tester) async {
    printTestDivider('ChatFileAttachment a download failure shows the could-not-download snackbar and resets the spinner');
    when(
      () => mockChatCubit.downloadAttachment(any(), any()),
    ).thenThrow(Exception('network error'));

    await pumpAttachment(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/invoice.pdf',
        fileName: 'invoice.pdf',
        type: AttachmentType.file,
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump();

    printTestLog(
      'snackbar message → expected: "${LanguageLabelKeys.couldNotDownloadFile}" visible',
    );
    expect(find.text(LanguageLabelKeys.couldNotDownloadFile), findsOneWidget);
    printTestLog(
      'spinner after failure → expected: gone, actual: ${find.byType(ShimmerInline).evaluate().length}',
    );
    expect(find.byType(ShimmerInline), findsNothing);
    printTestLog('opened → expected: none, actual: ${fakeOpenFile.opened}');
    expect(fakeOpenFile.opened, isEmpty);
  });

  testWidgets('an attachment with neither a local nor a remote source does nothing on tap', (tester) async {
    printTestDivider('ChatFileAttachment an attachment with neither a local nor a remote source does nothing on tap');
    await pumpAttachment(
      tester,
      const ChatAttachment(type: AttachmentType.file),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    printTestLog('opened → expected: none, actual: ${fakeOpenFile.opened}');
    expect(fakeOpenFile.opened, isEmpty);
    verifyNever(() => mockChatCubit.downloadAttachment(any(), any()));
  });

  testWidgets('a second tap while a download is in flight is ignored', (tester) async {
    printTestDivider('ChatFileAttachment a second tap while a download is in flight is ignored');
    final completer = Completer<void>();
    when(
      () => mockChatCubit.downloadAttachment(any(), any()),
    ).thenAnswer((_) => completer.future);

    await pumpAttachment(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/invoice.pdf',
        fileName: 'invoice.pdf',
        type: AttachmentType.file,
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.tap(find.byType(InkWell));
    await tester.pump();

    final calls = verify(
      () => mockChatCubit.downloadAttachment(any(), any()),
    )..called(1);
    printTestLog('download calls → expected: 1, actual: ${calls.callCount}');

    completer.complete();
    await tester.pump();
    await tester.pump();
  });
}
