<div align="center">

# MET v1.0

**Obsidian işlem günlüğünüz için MetaTrader 5 → Markdown işlem dışa aktarıcı**

[English](README.md) | [فارسی](README.fa.md) | **Türkçe** | [Azərbaycanca](README.az.md)

[Telegram](https://t.me/o2tribe) · [GitHub](https://github.com/sbbnm/mdexportermt5)

</div>

---

MET, MetaTrader 5 için bir Expert Advisor'dır (EA). **İşlem açmaz.** Yalnızca kapanmış pozisyonlarınızı okur ve her birini doğrudan Obsidian'a atabileceğiniz bir `.md` notu olarak yazar.

Her nota doğru **New York seansı**, **makro penceresi** ve **zaman dilimi (timeframe)** işlenir. Brokerınızın sunucu saati New York'tan farklı olsa bile (yaz/kış saati dahil dönüşüm sizin yerinize yapılır).

## Özellikler

- Kapanan her işlem için bir Markdown notu (`ticket`, sembol, yön, hacim, fiyatlar, SL/TP, R:R, bakiye, kâr, komisyon, swap, süre, sonuç ve daha fazlası).
- İşlem kapanır kapanmaz otomatik dışa aktarma; ayrıca Bugün / Bu Hafta / Bu Ay / Tüm Geçmiş / özel tarih aralığı için manuel dışa aktarma.
- Seans, makro ve timeframe tespiti ([Seanslar ve makrolar](#seanslar-ve-makrolar) bölümüne bakın).
- Broker saat diliminin otomatik tespiti veya herhangi bir UTC farkı ve yaz saati (DST) kuralıyla manuel ayar.
- Düzenlenebilir seans ve makro pencereleri, ek özel alanlar, koyu / açık / otomatik tema.
- DLL yok, internet erişimi yok: bilgisayarınızdan hiçbir şey dışarı çıkmaz.

## Ekran görüntüleri

<p align="center"><img src="images/overview.png" alt="Grafikte MET: sağda panel, solda ayarlar penceresi" width="820"><br><sub>Grafikte MET: sağda panel, solda ayarlar penceresi</sub></p>

<table align="center">
<tr>
<td align="center"><img src="images/panel.png" alt="Grafikteki panel" width="400"><br><sub>Grafikteki panel</sub></td>
<td align="center"><img src="images/settings-export.png" alt="Ayarlar: Export" width="400"><br><sub>Ayarlar: Export</sub></td>
</tr>
<tr>
<td align="center"><img src="images/settings-fields.png" alt="Ayarlar: Fields" width="400"><br><sub>Ayarlar: Fields</sub></td>
<td align="center"><img src="images/settings-timezones.png" alt="Ayarlar: Time Zones" width="400"><br><sub>Ayarlar: Time Zones</sub></td>
</tr>
<tr>
<td align="center"><img src="images/settings-sessions.png" alt="Ayarlar: Sessions" width="400"><br><sub>Ayarlar: Sessions</sub></td>
<td align="center"><img src="images/settings-advanced.png" alt="Ayarlar: Advanced" width="400"><br><sub>Ayarlar: Advanced</sub></td>
</tr>
<tr>
<td align="center"><img src="images/settings-about.png" alt="Ayarlar: About" width="400"><br><sub>Ayarlar: About</sub></td>
<td align="center"><img src="images/note-example.png" alt="Obsidian'da dışa aktarılmış bir not" width="400"><br><sub>Obsidian'da dışa aktarılmış bir not</sub></td>
</tr>
</table>

## Gereksinimler

- MetaTrader 5 (masaüstü sürümü), herhangi bir broker, demo veya gerçek hesap.
- Notları kullanmak için [Obsidian](https://obsidian.md). Oluşturulan notlar Dataview (`dataviewjs`) blokları içerir; tam deneyim için **Dataview** eklentisini kurun ve JavaScript sorgularını etkinleştirin.

## Kurulum

1. MetaTrader 5'te **File → Open Data Folder** seçeneğine tıklayın.
2. Açılan pencerede **MQL5** klasörünü, ardından **Experts** klasörünü açın.
3. **`MET_1.ex5`** dosyasını **Experts** klasörüne yapıştırın.
4. MetaTrader 5'e dönün ve **View → Navigator** seçeneğini açın (veya `Ctrl+N`).
5. Navigator'da **Expert Advisors** bölümüne sağ tıklayıp bir kez **Refresh** deyin. **MET** listede görünür.
6. **MET**'i bir grafiğe sürükleyin. **İşlem yapmadığınız** bir sembolün grafiğini kullanmanız önerilir (işlem grafiklerinizle karışmaması için).
7. **Inputs** sekmesinde **Account label** alanına broker veya hesap adınızı yazın (örneğin `FundedNext`) ve **OK**'e basın. Boş da bırakabilirsiniz.

Panel grafiğin sağ üst köşesinde görünür. **Algo Trading** düğmesinin açık olduğundan emin olun.

> Kaynak kodu kendiniz de derleyebilirsiniz: `MET.mq5` dosyasını MetaEditor'da açın ve `F7`'ye basın.

## Grafikteki panel

| Öğe | Ne yapar |
|---|---|
| **Broker / New York / Local** | Canlı saatler. New York saati ABD yaz/kış saatine otomatik uyar. |
| **DST satırı** | Broker ve New York'un şu an yaz mı kış saatinde mi olduğunu ve UTC farklarını gösterir. |
| **Range** | Şu an seçili dışa aktarma aralığı. |
| **Settings** | Ayarlar penceresini açar (grafiğin sol tarafında). |
| **EXPORT NOW** | Seçili aralıktaki işlemleri dışa aktarır. |
| **`>` oku** | Paneli gizler. Köşede küçük bir **`MET <`** düğmesi kalır; tıklayınca panel yeniden görünür. |

## Ayarlar penceresi (sekmeler)

### 1. Export

Neyin dışa aktarılacağını seçin ve **EXPORT NOW**'a basın.

- **Today**, **This Week** (Pazartesi'den itibaren), **This Month**, **All History**.
- **Custom Range**: *From* ve *To* tarihlerini `YYYY.MM.DD` biçiminde yazın. Tarihler broker sunucu saatine göredir ve *To* tarihi dahildir.

Düğmenin altındaki durum satırı kaç işlemin dışa aktarıldığını gösterir.

### 2. Fields

- Her nota yazılan **40 varsayılan alanı** gösterir (sabittir, silinemez; böylece Obsidian panolarınız bozulmaz):

  `ticket, account, account_id, broker, symbol, direction, volume, entry_price, exit_price, sl, tp, risk_amount, rr, open, close, ny_open, duration, balance_before, balance_after, equity_after, gross, commission, swap, net, result, strategy, setup, session, macro, news, timeframe, emotion, mistake, grade, review, notes, entry_images, exit_images, htf_images, tags`

- **Ek alanlar**: bir *Name* ve bir *Default value* yazıp **+ Add**'e basın. Alan, dışa aktarılan tüm notlara eklenir (`notes`'tan sonra). İsimdeki boşluklar `_` olur. **X** ile alan silinir. `news` alanı varsayılan olarak boştur, kendiniz doldurabilirsiniz.

### 3. Time Zones

MET her işlem saatini şöyle dönüştürür: **broker saati → GMT → New York saati → seans / makro**. Bu yüzden brokerınızın saat dilimini bilmesi gerekir.

- **Broker server time zone**
  - **Auto-detect** (varsayılan): sunucu saatini PC saatinizle karşılaştırır ve yaygın düzenleri (AB veya ABD yaz saati tarihleriyle GMT+2 / GMT+3) tanır. Hiçbiri uymazsa tespit edilen farkı sabit fark olarak kullanır. Düğmenin altındaki not neyin tespit edildiğini söyler. PC saatiniz ve PC saat diliminiz doğru olmalıdır.
  - **Manual**: bir **Preset** (şehir) seçin veya **Winter offset** (kışın UTC farkı) ile **Summer-time rule** (None / EU / US / Australia / New Zealand) ayarlayın. Örnekler: kışın GMT+2, yazın GMT+3 olan ve AB tarihlerine göre değişen broker → *Winter offset +2, rule EU*. Tüm yıl GMT+3'te sabit olan broker → *+3, rule None*.
- **Your own time zone**: yalnızca gösterim içindir (paneldeki "Local" saati).
- **Reference zone**: her zaman **New York** (GMT-5, ABD yaz saatinde GMT-4).
- Bu sekme ayrıca brokerın ve New York'un bu yılki **yaz saati değişim tarihlerini** ve canlı saatleri gösterir. Bunları brokerınızla karşılaştırın.

### 4. Sessions

Tüm saatler **New York saatidir**.

- **Sessions** (işlem uyan ilk seansı alır, yoksa `Closed`): başlangıç dahil, bitiş hariçtir (`24:00` = gece yarısı).
- **Macros** (yoksa `None`): başlangıç ve bitiş dakikaları ikisi de dahildir.
- Kendi penceranızı **name**, **from** ve **to** (`HH:MM`) ile ekleyin. Pencere gece yarısını aşabilir (örneğin `22:00 - 02:00`). **X** satırı siler, **Reset to defaults** varsayılanları geri yükler. Değişiklikler otomatik kaydedilir.

### 5. Advanced

- `timeframe` alanına yazılacak **Timeframe**:
  - **Auto**: MT5 bir işlemin timeframe'ini saklamaz; bu yüzden MET onu işlem açıldığında kaydeder (o sembolün açık grafikleri arasındaki en küçük timeframe). MET çalışmazken veya o sembolün grafiği açık değilken açılan işlemler **yedek değeri** alır (varsayılan `M1`, ya da boş).
  - **Manual**: her zaman seçtiğiniz timeframe'i yazar.
- **Panel theme**: Dark, Light veya Auto (grafik arka plan rengini izler).

### 6. About

Proje bağlantıları, destek için cüzdan adresi ve QR kod. Bir kutuya tıklayıp `Ctrl+C` ile kopyalayın (MT5 bağlantı açamaz).

## Dışa aktarılan dosyalar nerede?

1. MetaTrader 5'te **File → Open Data Folder** seçeneğine tıklayın.
2. **MQL5** klasörünü, sonra **Files**, sonra **Trades** klasörünü açın.
3. Her işlemin kendi ticket numarasıyla bir klasörü vardır: `MQL5\Files\Trades\<ticket>\Trade-<ticket>.md`.
4. `.md` dosyalarını (veya tüm **Trades** klasörünü) Obsidian vault'unuza kopyalayın.

> Bir işlem yeniden dışa aktarılırsa `MQL5\Files` içindeki dosyası üzerine yazılır. Dosyaları vault'unuza kopyalarken, daha önce düzenlediğiniz notların üzerine yazmayın.

## Seanslar ve makrolar

Varsayılanlar (New York saati). Seans ve makro **işlemin açılış zamanına** göre belirlenir.

| Seans | Saat |
|---|---|
| Asia | 20:00 – 24:00 |
| London | 02:00 – 05:00 |
| NewYork(AM) | 08:30 – 10:00 |
| Silver Bullet | 10:00 – 11:00 |
| NewYork Launch | 11:00 – 12:00 |
| NewYork(PM) | 13:30 – 16:00 |

| Makro | Saat |
|---|---|
| 8:50 - 9:10 | 08:50 – 09:10 |
| 9:50 - 10:10 | 09:50 – 10:10 |
| 10:50 - 11:10 | 10:50 – 11:10 |
| 13:50 - 14:10 | 13:50 – 14:10 |
| 15:15 - 15:30 | 15:15 – 15:30 |

## Bilmekte fayda var

- Ayarlar `MQL5\Files\ObsidianExport_Settings.cfg` dosyasına kaydedilir. Her şeyi sıfırlamak için bu dosyayı silin.
- Mesajlar ve hatalar MT5 Toolbox'taki **Experts** sekmesinde görünür.
- MET'i takmadan önce kapanmış işlemleri **EXPORT NOW** ile (aralığı seçerek) dışa aktarabilirsiniz.
- MET yalnızca geçmişinizi okur. Hiçbir işlemi açmaz, değiştirmez veya kapatmaz.

## Projeye destek

MET işinize yaradıysa bağış yaparak destek olabilirsiniz (EVM adresi: Ethereum, BSC, Polygon, Arbitrum, Optimism, Base ve diğer EVM ağlarında çalışır. Yalnızca EVM ağından gönderin; BTC veya TRON gibi başka ağlardan gönderilen fonlar kaybolur).

```
0x6a0F64332bDa0757A9C15C0A1C9E52F98b4d0282
```

<img src="donate-qr.png" alt="Donation QR code" width="180">

Sorular ve fikirler: [Telegram](https://t.me/o2tribe) · [GitHub Issues](https://github.com/sbbnm/mdexportermt5/issues)

## Sorumluluk reddi

MET bir günlük tutma aracıdır. Yatırım tavsiyesi değildir ve sizin yerinize işlem yapmaz. Dışa aktarılan verileri her zaman broker hesap özetinizle karşılaştırın.
