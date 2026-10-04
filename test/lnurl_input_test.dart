import 'package:flare/services/lnurl.dart';
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

  group('classifyLightningInput', () {
    const invoice =
        'lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpuaztrnwngzn3kdzw5hydlzf03qdgm2hdq27cqv3agm2awhz5se903vruatfhq77w3ls4evs3ch9zw97j25emudupq63nyw24cg27h2rspfj9srp';

    test('recognises LNURLs', () {
      expect(
        classifyLightningInput('lightning:$lower'),
        LightningInputKind.lnurl,
      );
      expect(
        classifyLightningInput(lower.toUpperCase()),
        LightningInputKind.lnurl,
      );
    });

    test('recognises payment requests', () {
      expect(
        classifyLightningInput('lightning:$invoice'),
        LightningInputKind.invoice,
      );
      expect(
        classifyLightningInput(invoice.toUpperCase()),
        LightningInputKind.invoice,
      );
      expect(
        classifyLightningInput(
          'lightning:lno1qsgqmqvgm96frzdg8m0gc6nzeqffvzsqzrxqy32afmr3jn9ggkwg3egfwch2hy0l6jut6vfd8vpsc3h89l6u3dm4q2d6nuamav3w27xvdmv3lpgklhg7l5teypqz9l53koj4vsr5nn',
        ),
        LightningInputKind.offer,
      );
    });

    test('recognises Lightning addresses', () {
      expect(
        classifyLightningInput('lightning:alice@example.com'),
        LightningInputKind.lightningAddress,
      );
      expect(
        classifyLightningInput('Alice@Example.com'),
        LightningInputKind.lightningAddress,
      );
    });

    test('treats everything else as unknown', () {
      expect(classifyLightningInput('hello'), LightningInputKind.unknown);
      expect(
        classifyLightningInput('https://example.com'),
        LightningInputKind.unknown,
      );
      expect(classifyLightningInput(''), LightningInputKind.unknown);
    });
  });

  group('LnurlService', () {
    final service = LnurlService();
    final k1 = 'ab' * 32;

    test('accepts LNURL-auth URLs', () {
      final r = service.parseLnurlAuth(
        Uri.parse('https://Example.com/auth?tag=login&k1=$k1&action=register'),
      );
      expect(r.domain, 'example.com');
      expect(r.action, 'register');
    });

    test('flags other LNURL types as unsupported', () {
      expect(
        () => service.parseLnurlAuth(
          Uri.parse('https://example.com/lnurlp/alice'),
        ),
        throwsA(isA<UnsupportedLinkException>()),
      );
      expect(
        () => service.parseLnurlAuth(
          Uri.parse('https://example.com/pay?tag=payRequest'),
        ),
        throwsA(isA<UnsupportedLinkException>()),
      );
    });

    test('still rejects bad k1 values', () {
      expect(
        () => service.parseLnurlAuth(
          Uri.parse('https://example.com/auth?tag=login&k1=nothex'),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e is UnsupportedLinkException,
            'unsupported',
            false,
          ),
        ),
      );
      expect(
        () => service.parseLnurlAuth(
          Uri.parse('https://example.com/auth?tag=login'),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
