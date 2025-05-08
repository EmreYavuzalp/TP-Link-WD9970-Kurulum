import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';


void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ModemSetupApp(), // sadece scaffold'ı içeren widget
  ));
}

class ModemSetupApp extends StatefulWidget {
  @override
  _ModemSetupAppState createState() => _ModemSetupAppState();
}

class _ModemSetupAppState extends State<ModemSetupApp> {
  late WebViewController _controller;
  bool isWebViewVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (String url) {
          // Sayfa yüklendikten sonra işlem yapılacak
        },
      ));
  }

  // Giriş işlemi fonksiyonu
  Future<void> loginWithFallback() async {
  await _controller.loadRequest(Uri.parse('http://192.168.1.1'));
  await Future.delayed(Duration(seconds: 1));

  // 1. turktelekom ile dene
  await _controller.runJavaScript('''
    document.getElementById("userName").value = "admin";
    document.getElementById("pcPassword").value = "turktelekom";
    document.getElementById("loginBtn").click();
  ''');

  await Future.delayed(Duration(seconds: 2));

  // note ID'li öğe var mı diye kontrol et
  var result = await _controller.runJavaScriptReturningResult('''
    document.getElementById("note") ? true : false;
  ''');

  if (result == true || result.toString() == 'true') {
    // Şifre yanlış, ttnet ile tekrar dene
    await _controller.loadRequest(Uri.parse('http://192.168.1.1'));
    await Future.delayed(Duration(seconds: 1));

    await _controller.runJavaScript('''
      document.getElementById("userName").value = "admin";
      document.getElementById("pcPassword").value = "ttnet";
      document.getElementById("loginBtn").click();
    ''');

    await Future.delayed(Duration(seconds: 2));

    var secondTry = await _controller.runJavaScriptReturningResult('''
      document.getElementById("note") ? true : false;
    ''');

    if (secondTry == true || secondTry.toString() == 'true') {
      // Her iki şifre de yanlışsa kullanıcıyı uyar
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Şifre farklı"),
            content: Text("Şifre turktelekom veya ttnet değil, hard reset deneyin."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Tamam"),
              )
            ],
          ),
        );
      }
    }
  }
}


Future<void> skipSteps() async {
  // İlk geçme adımı: #skipBtn varsa tıkla
  var skipBtnExists = await _controller.runJavaScriptReturningResult('''
    document.getElementById("skipBtn") ? true : false;
  ''');
  
  if (skipBtnExists == true || skipBtnExists.toString() == 'true') {
    await _controller.runJavaScript('''
      document.getElementById("skipBtn").click();
    ''');
    await Future.delayed(Duration(seconds: 1)); // biraz bekleyelim
  }

  // İkinci geçme adımı: div.btn varsa tıkla
  var divBtnExists = await _controller.runJavaScriptReturningResult('''
    document.querySelector("div.btn") ? true : false;
  ''');

  if (divBtnExists == true || divBtnExists.toString() == 'true') {
    await _controller.runJavaScript('''
      document.querySelector("div.btn").click();
    ''');
    await Future.delayed(Duration(seconds: 4));
  }
}

Future<void> navigateQuickSetup() async {
  // 1. Kolay Menü
  var kolayMenuExists = await _controller.runJavaScriptReturningResult('''
    [...document.links].some(link => link.textContent.trim() === "Kolay Menü")
  ''');

  if (kolayMenuExists == true || kolayMenuExists.toString() == 'true') {
    await _controller.runJavaScript('''
      [...document.links].find(link => link.textContent.trim() === "Kolay Menü").click();
    ''');
    await Future.delayed(Duration(seconds: 2));
  }

  // 2. Hızlı Kurulum
  var hizliKurulumExists = await _controller.runJavaScriptReturningResult('''
    [...document.links].some(link => link.textContent.trim() === "Hızlı Kurulum")
  ''');

  if (hizliKurulumExists == true || hizliKurulumExists.toString() == 'true') {
    await _controller.runJavaScript('''
      [...document.links].find(link => link.textContent.trim() === "Hızlı Kurulum").click();
    ''');
    await Future.delayed(Duration(seconds: 2));
  }

  // 3. Sonraki buton
  var buttonExists = await _controller.runJavaScriptReturningResult('''
    document.getElementsByClassName("button").length > 0
  ''');

  if (buttonExists == true || buttonExists.toString() == 'true') {
    await _controller.runJavaScript('''
      document.getElementsByClassName("button")[0].click();
    ''');
    await Future.delayed(Duration(seconds: 1));
 
  }
   // Son işlemden sonra küçük bekleme süresi
  await Future.delayed(Duration(milliseconds: 1000));

  // WebView'ı gizle
  setState(() {
    isWebViewVisible = false;
  });

  // Bilgi kutusunu göster
  await showLoginInfoDialog(context);

  // (İsteğe bağlı) WebView'ı tekrar göster
  setState(() {
    isWebViewVisible = true;
  });
}

Future<void> showLoginInfoDialog(BuildContext context) async {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Kullanıcı Adı ve Şifre Bilgisi"),
        content: SingleChildScrollView(
          child: Text(
            "Buradaki kullanıcı adını ve şifreyi, eğer Türktelekom kullanıyorsanız 444 03 75 i arayıp alabilirsiniz. "
            "Önce 'teknik destek almak istiyorum' u seçip, sonrasında da 'internet kullanıcı adı ve şifremi almak istiyorum' a basınız. "
            "Türknet için ise, Online İşlem Merkezi'nden alabilirsiniz.",
            style: TextStyle(fontSize: 16),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text("Tamam"),
            onPressed: () {
              Navigator.of(context).pop(); // Dialog'ı kapat
            },
          ),
        ],
      );
    },
  );
}



  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text("TP-Link Modem Arayüzü"),
    ),
    body: isWebViewVisible
        ? WebViewWidget(controller: _controller)
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Lütfen modemin kablosuz ağından bağlanın. Eğer kablosuz ağına bağlanmazsanız program çalışmayacaktır. "
                      "Mobil veriyi kapatın. Ünlem işareti veya internet olmadan bağlan gibi uyarılar çıkabilir, "
                      "ki burada internet olmadan bağlan a tıklayınız. Daha sonra buradaki giriş yap butonuna tıklarsanız "
                      "modem arayüzüne bağlanacaksınız. Program bir yerde donarsa, kurulum rehberindeki adımları izleyerek devam edebilirsiniz.",
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      isWebViewVisible = true;
                    });
                    await loginWithFallback();
                    await skipSteps();
                    await navigateQuickSetup();
                  },
                  child: Text("Başla"),
                ),
              ),
            ],
          ),
  );
}
}