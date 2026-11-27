// UTC transition instants for Asia/Gaza (IANA tzdata); indexed by calendar year.
class FacilityTime {
  static const _summer = [
    1585346400,
    1616796000,
    1648332000,
    1682726400,
    1713571200,
    1744416000,
    1774656000,
    1806105600,
    1837555200,
    1869004800,
    1901059200,
    1932508800,
    1963958400,
    1995408000,
    2026857600,
    2058307200,
  ];
  static const _winter = [
    1603490400,
    1635458400,
    1666998000,
    1698447600,
    1729897200,
    1761346800,
    1792796400,
    1824850800,
    1856300400,
    1887750000,
    1919199600,
    1950649200,
    1982703600,
    2014153200,
    2045602800,
    2077052400,
  ];

  static DateTime wall(DateTime instant) {
    final utc = instant.toUtc();
    final i = utc.year - 2020;
    if (i < 0 || i >= _summer.length)
      throw StateError('Unsupported facility calendar year.');
    final seconds = utc.millisecondsSinceEpoch ~/ 1000;
    return utc.add(
      Duration(hours: seconds >= _summer[i] && seconds < _winter[i] ? 3 : 2),
    );
  }
}
