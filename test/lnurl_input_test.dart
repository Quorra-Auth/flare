import 'package:flare/utils/lnurl_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lower =
      'lnurl1dp68gurn8ghj7ut4dae8ycfwdvuxjefwdahx2tmvde6hympdv96hg6p0wfjkw6tnw3jhy0mtxy7nzerrvg6r2etzxajrvdmpxumnzen9vyunqdpnxqmrqefkv5enjvej8yurxwrzxsmx2c33vvcxvcf4v5uxgd3e8qcxyefhxd3kzcfcxsn8gct884kx7emfdcnxzcm5d9hku0tjv4nkjum5v4ezvum9wfmx2u3aw96k7unjvyc9s2wu';

  test('accepts lightning: URIs', () {
    expect(extractLnurl('lightning:$lower'), lower);
    expect(extractLnurl('LIGHTNING:${lower.toUpperCase()}'), lower);
    expect(extractLnurl('lightning://$lower'), lower);
  });

  test('accepts bare and uppercase LNURLs', () {
    expect(extractLnurl(lower), lower);
    expect(extractLnurl('  ${lower.toUpperCase()}\n'), lower);
  });

  test('accepts web fallback URLs with a lightning parameter', () {
    expect(extractLnurl('https://example.com/login?lightning=$lower'), lower);
  });

  test('rejects anything else', () {
    expect(extractLnurl(''), isNull);
    expect(extractLnurl('https://example.com'), isNull);
    expect(extractLnurl('hello world'), isNull);
    expect(extractLnurl('lightning:lnbc1notanlnurl'), isNull);
    expect(extractLnurl('lnurl1'), isNull);
  });
}
