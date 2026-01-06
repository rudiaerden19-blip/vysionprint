# Vysion Print - iOS App

iOS app voor het printen van bonnen naar WiFi bonnenprinters vanuit de Vysion Horeca kassa.

## ✨ Features

- 🔍 **Automatisch printers zoeken** - Scant je WiFi netwerk
- 🖨️ **Alle bonnenprinters** - Epson, Star, Bixolon, Citizen, etc.
- 📱 **HTTP Server** - Ontvangt print opdrachten van de kassa
- 💰 **Kassalade** - Open de kassalade vanuit de kassa
- ⚙️ **Handmatige configuratie** - IP + poort instelbaar

## 📱 Ondersteunde printers

Alle WiFi bonnenprinters die ESC/POS ondersteunen:

| Merk | Modellen |
|------|----------|
| Epson | TM-T20, TM-T20II, TM-T20III, TM-T88 |
| Star | TSP100, TSP650, mC-Print |
| Bixolon | SRP-330, SRP-350 |
| Citizen | CT-S310, CT-S2000 |
| Sewoo | LK-T21 |
| Xprinter | XP-58, XP-80 |

## 🚀 Installatie

### Vereisten

- iPad met iOS 16 of hoger
- Mac met Xcode 15 of hoger
- WiFi bonnenprinter

### Stap 1: Project openen

```bash
open ~/VysionPrint/VysionPrint.xcodeproj
```

### Stap 2: Signing configureren

1. Open project in Xcode
2. Selecteer "VysionPrint" target
3. Ga naar "Signing & Capabilities"
4. Selecteer je Team (Apple ID)
5. Pas Bundle Identifier aan (bijv. `com.jouwbedrijf.vysionprint`)

### Stap 3: Op iPad draaien

**Met kabel:**
1. Sluit iPad aan op Mac
2. Selecteer je iPad als target
3. Klik Run (▶️)
4. Vertrouw developer op iPad: Instellingen → Algemeen → VPN en apparaatbeheer

**Draadloos:**
1. Sluit iPad eerst één keer aan met kabel
2. Xcode: Window → Devices and Simulators
3. Vink aan: "Connect via network"
4. Daarna kun je draadloos deployen

### Stap 4: In de app

1. Open Vysion Print op je iPad
2. Klik **"Zoek printers"** - de app scant je netwerk
3. Selecteer je printer uit de lijst
4. Of: vul handmatig IP + poort in
5. Klik **"Test Print"** om te testen

### Stap 5: Kassa configureren

1. Open de Vysion Kassa op je iPad (Safari)
2. Ga naar **Instellingen → Printers**
3. Zet **"Vysion Print Server"** aan
4. Vul het IP-adres van je iPad in (getoond in de app)
5. Test met **"Test Verbinding"**

## 📡 API Endpoints

De app draait een HTTP server op poort 3001:

| Endpoint | Methode | Beschrijving |
|----------|---------|--------------|
| `/` | GET | Status pagina (HTML) |
| `/status` | GET | Server status (JSON) |
| `/print` | POST | Print een bon |
| `/drawer` | POST | Open kassalade |
| `/test` | POST | Test print |

### Print request voorbeeld

```json
POST /print
Content-Type: application/json

{
  "order": {
    "orderNumber": 123,
    "orderType": "TAKEAWAY",
    "items": [
      {
        "quantity": 2,
        "name": "Friet",
        "totalPrice": 5.00
      }
    ],
    "subtotal": 5.00,
    "tax": 0.87,
    "total": 5.87,
    "paymentMethod": "CASH"
  },
  "businessInfo": {
    "name": "Mijn Zaak",
    "address": "Straat 1",
    "postalCode": "1234 AB",
    "city": "Stad",
    "phone": "012-3456789",
    "vatNumber": "BE0123456789"
  }
}
```

## 🔧 Poorten

| Poort | Gebruik |
|-------|---------|
| 3001 | HTTP server (kassa → app) |
| 9100 | Printer (standaard ESC/POS) |

Als je printer op een andere poort draait, kun je dit handmatig instellen in de app.

## ❓ Troubleshooting

### Geen printers gevonden bij scannen

- Check of iPad en printer op hetzelfde WiFi zitten
- Check of de printer aan staat
- Probeer handmatig het IP in te voeren (print statusbon van printer)

### Print werkt niet

- Check printer IP/poort in de app
- Stuur een test print om verbinding te testen
- Check of de printer papier heeft

### Kassa kan app niet bereiken

- Check of de Vysion Print app open staat
- Check of je het juiste iPad IP-adres hebt ingevuld
- iPad en kassa moeten op hetzelfde WiFi zitten

### App sluit af op achtergrond

iOS kan apps op de achtergrond sluiten. Houd de app open of:
- Ga naar Instellingen → Vysion Print → App-vernieuwing: Aan

## 🛒 App Store (voor klanten)

Zodra je Apple Developer account actief is:

1. Xcode: Product → Archive
2. Upload naar App Store Connect
3. Ga naar [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
4. Maak een nieuwe app aan
5. **TestFlight**: Voeg testers toe voor beta testing
6. **App Store**: Submit voor review

## 📞 Support

Hulp nodig? support@vysion-horeca.be
