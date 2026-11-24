package io.github.kimhershey.gagyebu

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 다른 앱의 "공유"로 받은 글을 Dart로 넘긴다(docs/SPEC.md 7.18).
 *
 * 받은 글은 여기 들고 있다가 Dart가 `take`로 가져간다. 앱이 떠 있는 동안 새로 받으면
 * `changed`로 알리기만 하고, 글은 역시 `take`로 가져가게 한다. 그래야 Dart가 아직 듣기 전에
 * 받은 글(앱을 띄운 공유)도 같은 길로 간다. Dart 쪽은 lib/platform/share_receiver.dart다.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** 받았지만 Dart가 아직 가져가지 않은 글. */
    private var pendingText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // 시스템이 화면을 되살린 경우(savedInstanceState가 있다)에는 처음의 공유 인텐트가 다시
        // 온다. 이미 넘긴 글이므로 읽지 않는다.
        if (savedInstanceState == null) {
            pendingText = sharedText(intent)
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.kimhershey.gagyebu/share",
        )
        channel.setMethodCallHandler { call, result ->
            if (call.method == "take") {
                result.success(pendingText)
                pendingText = null
            } else {
                result.notImplemented()
            }
        }
        this.channel = channel
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = sharedText(intent) ?: return
        pendingText = text
        channel?.invokeMethod("changed", null)
    }

    /** 글을 공유하는 인텐트면 그 글을, 아니면 null을 돌려준다. */
    private fun sharedText(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_SEND) return null
        // 최근 앱 목록에서 다시 열면 예전의 공유 인텐트가 그대로 온다. 새 공유가 아니다.
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return null
        return intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
    }
}
