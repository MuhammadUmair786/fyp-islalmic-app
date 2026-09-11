class AyahRef {
  final int surah;
  final int ayah;
  AyahRef(this.surah, this.ayah);
}

class MoodCategory {
  final String name;
  final String icon;
  final List<AyahRef> refs;

  MoodCategory({required this.name, required this.icon, required this.refs});
}

final List<MoodCategory> moodDataset = [
  MoodCategory(
    name: "Sad",
    icon: "😔",
    refs: [
      AyahRef(94, 5), AyahRef(93, 3), AyahRef(12, 86), AyahRef(2, 214), AyahRef(3, 139),
      AyahRef(10, 65), AyahRef(9, 40), AyahRef(21, 88), AyahRef(39, 53), AyahRef(46, 13),
    ],
  ),
  MoodCategory(
    name: "Anxious",
    icon: "😰",
    refs: [
      AyahRef(13, 28), AyahRef(2, 286), AyahRef(65, 2), AyahRef(2, 153), AyahRef(94, 7),
      AyahRef(40, 44), AyahRef(2, 186), AyahRef(3, 173), AyahRef(8, 40), AyahRef(20, 25),
    ],
  ),
  MoodCategory(
    name: "Angry",
    icon: "😠",
    refs: [
      AyahRef(3, 134), AyahRef(41, 34), AyahRef(7, 199), AyahRef(42, 40), AyahRef(42, 43),
      AyahRef(7, 200), AyahRef(25, 63), AyahRef(15, 85), AyahRef(3, 159), AyahRef(23, 96),
    ],
  ),
  MoodCategory(
    name: "Lonely",
    icon: "👤",
    refs: [
      AyahRef(50, 16), AyahRef(2, 152), AyahRef(6, 59), AyahRef(57, 4), AyahRef(21, 87),
      AyahRef(2, 257), AyahRef(17, 80), AyahRef(9, 129), AyahRef(8, 64), AyahRef(2, 107),
    ],
  ),
  MoodCategory(
    name: "Grateful",
    icon: "😇",
    refs: [
      AyahRef(14, 7), AyahRef(55, 13), AyahRef(27, 40), AyahRef(16, 18), AyahRef(2, 172),
      AyahRef(4, 147), AyahRef(93, 11), AyahRef(31, 12), AyahRef(6, 45), AyahRef(39, 66),
    ],
  ),
  MoodCategory(
    name: "Fearful",
    icon: "😨",
    refs: [
      AyahRef(3, 175), AyahRef(65, 3), AyahRef(20, 46), AyahRef(2, 38), AyahRef(33, 3),
      AyahRef(1, 5), AyahRef(8, 2), AyahRef(10, 107), AyahRef(59, 23), AyahRef(2, 256),
    ],
  ),
];
