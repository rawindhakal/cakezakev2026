// Shared payment-gateway defaults + currency-code option lists.
// Used by the Country form (currency + gateways are country-scoped).

/**
 * Which mode each gateway starts in, and falls back to.
 *
 * A gateway is never in no mode at all: an empty one would reach the gateway as a blank
 * environment and fail at the first call. Sandbox is the safe end to default to —
 * PhonePe calls the same thing `uat`.
 */
export const defaultModes = {
    paypal_mode: 'sandbox',
    stripe_mode: 'sandbox',
    midtrans_mode: 'sandbox',
    phonepay_mode: 'uat',
    cashfree_mode: 'sandbox',
    paytabs_mode: 'sandbox',
    cod_mode: 'global',
};

export function defaultGateways() {
    return {
        payment_method_settings: 1,
        cod_payment_method: 0, cod_mode: defaultModes.cod_mode,
        counter_payment_method: 0, counter_instructions: '',
        esewa_payment_method: 0, esewa_id: '', esewa_account_name: '', esewa_qr_image: '', esewa_instructions: '',
        bank_payment_method: 0, bank_name: '', bank_account_name: '', bank_account_number: '', bank_branch: '', bank_instructions: '',
        qr_payment_method: 0, qr_image: '', qr_instructions: '',
        paypal_payment_method: 0, paypal_mode: defaultModes.paypal_mode, paypal_currency_code: '',
        paypal_client_id: '', paypal_client_secret: '', paypal_webhook_id: '',
        razorpay_payment_method: 0, razorpay_key: '', razorpay_secret_key: '',
        paystack_payment_method: 0, paystack_public_key: '', paystack_secret_key: '', paystack_currency_code: '',
        stripe_payment_method: 0, stripe_mode: defaultModes.stripe_mode, stripe_publishable_key: '', stripe_secret_key: '',
        stripe_webhook_secret_key: '', stripe_currency_code: '',
        midtrans_payment_method: 0, midtrans_mode: defaultModes.midtrans_mode, midtrans_server_key: '',
        phonepay_payment_method: 0, phonepay_mode: defaultModes.phonepay_mode, phonepay_merchant_id: '', phonepay_client_id: '',
        phonepay_client_version: '', phonepay_client_secret: '',
        cashfree_payment_method: 0, cashfree_mode: defaultModes.cashfree_mode, cashfree_app_id: '', cashfree_secret_key: '',
        paytabs_payment_method: 0, paytabs_mode: defaultModes.paytabs_mode, paytabs_profile_id: '', paytabs_secret_key: '',
    };
}

/**
 * A country saved before a mode had a default carries an empty one. Fill those in on
 * load, so the dropdown always shows a real choice rather than a blank line.
 */
export function fillMissingModes(gateways) {
    Object.entries(defaultModes).forEach(([key, value]) => {
        if (!gateways[key]) {
            gateways[key] = value;
        }
    });

    return gateways;
}

export const currencyOptions = {
    paypal: [
        { c: 'INR', n: 'Indian rupee' }, { c: 'AUD', n: 'Australian dollar' }, { c: 'BRL', n: 'Brazilian real' },
        { c: 'CAD', n: 'Canadian dollar' }, { c: 'CNY', n: 'Chinese Renmenbi' }, { c: 'CZK', n: 'Czech koruna' },
        { c: 'DKK', n: 'Danish krone' }, { c: 'EUR', n: 'Euro' }, { c: 'HKD', n: 'Hong Kong dollar' },
        { c: 'HUF', n: 'Hungarian forint' }, { c: 'ILS', n: 'Israeli new shekel' }, { c: 'JPY', n: 'Japanese yen' },
        { c: 'MYR', n: 'Malaysian ringgit' }, { c: 'MXN', n: 'Mexican peso' }, { c: 'TWD', n: 'New Taiwan dollar' },
        { c: 'NZD', n: 'New Zealand dollar' }, { c: 'NOK', n: 'Norwegian krone' }, { c: 'PHP', n: 'Philippine peso' },
        { c: 'PLN', n: 'Polish złoty' }, { c: 'GBP', n: 'Pound sterling' }, { c: 'RUB', n: 'Russian ruble' },
        { c: 'SGD', n: 'Singapore dollar' }, { c: 'SEK', n: 'Swedish krona' }, { c: 'CHF', n: 'Swiss franc' },
        { c: 'THB', n: 'Thai baht' }, { c: 'USD', n: 'United States dollar' },
    ],
    paystack: [
        { c: 'GHS', n: 'Ghana - GHS' }, { c: 'NGN', n: 'Nigeria - NGN' }, { c: 'USD', n: 'United States - USD' },
        { c: 'ZAR', n: 'South Africa - ZAR' }, { c: 'KES', n: 'Kenya - KES' },
    ],
    stripe: [
        { c: 'INR', n: 'Indian rupee' }, { c: 'USD', n: 'United States dollar' }, { c: 'AED', n: 'United Arab Emirates Dirham' },
        { c: 'AFN', n: 'Afghan Afghani' }, { c: 'ALL', n: 'Albanian Lek' }, { c: 'AMD', n: 'Armenian Dram' },
        { c: 'ANG', n: 'Netherlands Antillean Guilder' }, { c: 'AOA', n: 'Angolan Kwanza' }, { c: 'ARS', n: 'Argentine Peso' },
        { c: 'AUD', n: 'Australian Dollar' }, { c: 'AWG', n: 'Aruban Florin' }, { c: 'AZN', n: 'Azerbaijani Manat' },
        { c: 'BAM', n: 'Bosnia-Herzegovina Convertible Mark' }, { c: 'BBD', n: 'Bajan dollar' }, { c: 'BDT', n: 'Bangladeshi Taka' },
        { c: 'BGN', n: 'Bulgarian Lev' }, { c: 'BIF', n: 'Burundian Franc' }, { c: 'BMD', n: 'Bermudan Dollar' },
        { c: 'BND', n: 'Brunei Dollar' }, { c: 'BOB', n: 'Bolivian Boliviano' }, { c: 'BRL', n: 'Brazilian Real' },
        { c: 'BSD', n: 'Bahamian Dollar' }, { c: 'BWP', n: 'Botswanan Pula' }, { c: 'BZD', n: 'Belize Dollar' },
        { c: 'CAD', n: 'Canadian Dollar' }, { c: 'CDF', n: 'Congolese Franc' }, { c: 'CHF', n: 'Swiss Franc' },
        { c: 'CLP', n: 'Chilean Peso' }, { c: 'CNY', n: 'Chinese Yuan' }, { c: 'COP', n: 'Colombian Peso' },
        { c: 'CRC', n: 'Costa Rican Colón' }, { c: 'CVE', n: 'Cape Verdean Escudo' }, { c: 'CZK', n: 'Czech Koruna' },
        { c: 'DJF', n: 'Djiboutian Franc' }, { c: 'DKK', n: 'Danish Krone' }, { c: 'DOP', n: 'Dominican Peso' },
        { c: 'DZD', n: 'Algerian Dinar' }, { c: 'EGP', n: 'Egyptian Pound' }, { c: 'ETB', n: 'Ethiopian Birr' },
        { c: 'EUR', n: 'Euro' }, { c: 'FJD', n: 'Fijian Dollar' }, { c: 'FKP', n: 'Falkland Island Pound' },
        { c: 'GBP', n: 'Pound sterling' }, { c: 'GEL', n: 'Georgian Lari' }, { c: 'GIP', n: 'Gibraltar Pound' },
        { c: 'GMD', n: 'Gambian dalasi' }, { c: 'GNF', n: 'Guinean Franc' }, { c: 'GTQ', n: 'Guatemalan Quetzal' },
        { c: 'GYD', n: 'Guyanaese Dollar' }, { c: 'HKD', n: 'Hong Kong Dollar' }, { c: 'HNL', n: 'Honduran Lempira' },
        { c: 'HRK', n: 'Croatian Kuna' }, { c: 'HTG', n: 'Haitian Gourde' }, { c: 'HUF', n: 'Hungarian Forint' },
        { c: 'IDR', n: 'Indonesian Rupiah' }, { c: 'ILS', n: 'Israeli New Shekel' }, { c: 'ISK', n: 'Icelandic Króna' },
        { c: 'JMD', n: 'Jamaican Dollar' }, { c: 'JPY', n: 'Japanese Yen' }, { c: 'KES', n: 'Kenyan Shilling' },
        { c: 'KGS', n: 'Kyrgystani Som' }, { c: 'KHR', n: 'Cambodian riel' }, { c: 'KMF', n: 'Comorian franc' },
        { c: 'KRW', n: 'South Korean won' }, { c: 'KYD', n: 'Cayman Islands Dollar' }, { c: 'KZT', n: 'Kazakhstani Tenge' },
        { c: 'LAK', n: 'Laotian Kip' }, { c: 'LBP', n: 'Lebanese pound' }, { c: 'LKR', n: 'Sri Lankan Rupee' },
        { c: 'LRD', n: 'Liberian Dollar' }, { c: 'LSL', n: 'Lesotho loti' }, { c: 'MAD', n: 'Moroccan Dirham' },
        { c: 'MDL', n: 'Moldovan Leu' }, { c: 'MGA', n: 'Malagasy Ariary' }, { c: 'MKD', n: 'Macedonian Denar' },
        { c: 'MMK', n: 'Myanmar Kyat' }, { c: 'MNT', n: 'Mongolian Tugrik' }, { c: 'MOP', n: 'Macanese Pataca' },
        { c: 'MRO', n: 'Mauritanian Ouguiya' }, { c: 'MUR', n: 'Mauritian Rupee' }, { c: 'MVR', n: 'Maldivian Rufiyaa' },
        { c: 'MWK', n: 'Malawian Kwacha' }, { c: 'MXN', n: 'Mexican Peso' }, { c: 'MYR', n: 'Malaysian Ringgit' },
        { c: 'MZN', n: 'Mozambican metical' }, { c: 'NAD', n: 'Namibian dollar' }, { c: 'NGN', n: 'Nigerian Naira' },
        { c: 'NIO', n: 'Nicaraguan Córdoba' }, { c: 'NOK', n: 'Norwegian Krone' }, { c: 'NPR', n: 'Nepalese Rupee' },
        { c: 'NZD', n: 'New Zealand Dollar' }, { c: 'PAB', n: 'Panamanian Balboa' }, { c: 'PEN', n: 'Sol' },
        { c: 'PGK', n: 'Papua New Guinean Kina' }, { c: 'PHP', n: 'Philippine peso' }, { c: 'PKR', n: 'Pakistani Rupee' },
        { c: 'PLN', n: 'Poland złoty' }, { c: 'PYG', n: 'Paraguayan Guarani' }, { c: 'QAR', n: 'Qatari Rial' },
        { c: 'RON', n: 'Romanian Leu' }, { c: 'RSD', n: 'Serbian Dinar' }, { c: 'RUB', n: 'Russian Ruble' },
        { c: 'RWF', n: 'Rwandan franc' }, { c: 'SAR', n: 'Saudi Riyal' }, { c: 'SBD', n: 'Solomon Islands Dollar' },
        { c: 'SCR', n: 'Seychellois Rupee' }, { c: 'SEK', n: 'Swedish Krona' }, { c: 'SGD', n: 'Singapore Dollar' },
        { c: 'SHP', n: 'Saint Helenian Pound' }, { c: 'SLL', n: 'Sierra Leonean Leone' }, { c: 'SOS', n: 'Somali Shilling' },
        { c: 'SRD', n: 'Surinamese Dollar' }, { c: 'STD', n: 'Sao Tome Dobra' }, { c: 'SZL', n: 'Swazi Lilangeni' },
        { c: 'THB', n: 'Thai Baht' }, { c: 'TJS', n: 'Tajikistani Somoni' }, { c: 'TOP', n: 'Tongan Paʻanga' },
        { c: 'TRY', n: 'Turkish lira' }, { c: 'TTD', n: 'Trinidad & Tobago Dollar' }, { c: 'TWD', n: 'New Taiwan dollar' },
        { c: 'TZS', n: 'Tanzanian Shilling' }, { c: 'UAH', n: 'Ukrainian hryvnia' }, { c: 'UGX', n: 'Ugandan Shilling' },
        { c: 'UYU', n: 'Uruguayan Peso' }, { c: 'UZS', n: 'Uzbekistani Som' }, { c: 'VND', n: 'Vietnamese dong' },
        { c: 'VUV', n: 'Vanuatu Vatu' }, { c: 'WST', n: 'Samoa Tala' }, { c: 'XAF', n: 'Central African CFA franc' },
        { c: 'XCD', n: 'East Caribbean Dollar' }, { c: 'XOF', n: 'West African CFA franc' }, { c: 'XPF', n: 'CFP Franc' },
        { c: 'YER', n: 'Yemeni Rial' }, { c: 'ZAR', n: 'South African Rand' }, { c: 'ZMW', n: 'Zambian Kwacha' },
    ],
};

export function gatewayWebhookUrls(baseUrl, siteUrl) {
    const base = (baseUrl || '').replace(/\/$/, '');
    const site = (siteUrl || '').replace(/\/$/, '');
    return {
        paypal: base + '/webhook/paypal',
        stripe: base + '/webhook/stripe',
        midtrans: base + '/midtrans/callback',
        midtransReturn: site + '/web-payment-status',
        cashfree: base + '/cashfree/callback',
        paytabs: base + '/paytabs/callback',
    };
}
