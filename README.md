# Vysion Print - iOS App

iOS app voor het printen van bonnen naar Epson WiFi printers vanuit de Vysion Horeca kassa.

## Wat doet deze app?

1. Draait een HTTP server op je iPad (poort 3001)
2. Ontvangt print opdrachten van de Vysion Horeca kassa
3. Stuurt ESC/POS commando's naar je Epson printer

## Vereisten

- iPad met iOS 16 of hoger
- Apple Developer Program account (€99/jaar)
- Epson TM-T20/T20II/T20III met WiFi
- Xcode 15 of hoger

## Installatie

### 1. Apple Developer Account

1. Ga naar [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/)
2. Koop het Apple Developer Program (€99/jaar)
3. Wacht op activatie (24-48 uur)

### 2. Project openen

1. Open Xcode
2. Open het project: `~/VysionPrint/VysionPrint.xcodeproj`
3. Selecteer je Team in Signing & Capabilities
4. Verander de Bundle Identifier naar iets unieks (bijv. `com.jouwbedrijf.vysionprint`)

### 3. Op iPad draaien

1. Sluit je iPad aan via USB
2. Selecteer je iPad als target device
3. Klik op Run (▶️)
4. Vertrouw de developer op je iPad (Instellingen → Algemeen → VPN en apparaatbeheer)

### 4. TestFlight (voor klanten)

1. In Xcode: Product → Archive
2. Upload naar App Store Connect
3. Ga naar [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
4. Maak een nieuwe app aan
5. Ga naar TestFlight → voeg testers toe
6. Stuur de TestFlight link naar je klanten

## Gebruik

### In de app

1. Open Vysion Print op je iPad
2. Vul het IP-adres van je Epson printer in
3. Klik op "Test Print" om te testen
4. Laat de app open staan (op de achtergrond)

### In de kassa

De kassa stuurt automatisch print opdrachten naar de iPad app.

## API Endpoints

De app draait een HTTP server op poort 3001:

| Endpoint | Methode | Beschrijving |
|----------|---------|--------------|
| `/status` | GET | Server status |
| `/print` | POST | Print een bon |
| `/drawer` | POST | Open kassalade |
| `/test` | POST | Test print |

### Voorbeeld print request

```json
POST /print
{
  "order": {
    "orderNumber": 123,
    "orderType": "TAKEAWAY",
    "items": [
      {
        "quantity": 2,
        "menuItem": { "name": "Friet" },
        "totalPrice": 5.00
      }
    ],
    "subtotal": 5.00,
    "tax": 0.45,
    "total": 5.45,
    "paymentMethod": "CASH"
  },
  "businessInfo": {
    "name": "Mijn Zaak",
    "address": "Straat 1",
    "city": "Stad"
  }
}
```

## Troubleshooting

### App sluit af op achtergrond
iOS sluit apps af die op de achtergrond draaien. Houd de app open of gebruik Background Modes.

### Printer reageert niet
- Check of de printer aan staat
- Check of iPad en printer op hetzelfde WiFi zitten
- Check het IP-adres van de printer

### Verbinding geweigerd
- Check of de app draait
- Check of je het juiste IP-adres van de iPad gebruikt in de kassa

## Support

Hulp nodig? support@vysion-horeca.be
