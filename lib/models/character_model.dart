class CharacterModel {
  const CharacterModel({
    required this.id,
    required this.name,
    required this.status,
    required this.species,
    required this.gender,
    required this.originName,
    required this.locationName,
    required this.image,
  });

  final int id;
  final String name;
  final String status;
  final String species;
  final String gender;
  final String originName;
  final String locationName;
  final String image;

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    final origin = json['origin'];
    final location = json['location'];

    return CharacterModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? 'Unknown',
      status: (json['status'] as String?) ?? 'unknown',
      species: (json['species'] as String?) ?? 'Unknown',
      gender: (json['gender'] as String?) ?? 'Unknown',
      originName: origin is Map<String, dynamic>
          ? (origin['name'] as String?) ?? 'Unknown'
          : (json['originName'] as String?) ?? 'Unknown',
      locationName: location is Map<String, dynamic>
          ? (location['name'] as String?) ?? 'Unknown'
          : (json['locationName'] as String?) ?? 'Unknown',
      image: (json['image'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'species': species,
      'gender': gender,
      'origin': {'name': originName},
      'location': {'name': locationName},
      'image': image,
    };
  }
}

class PaginatedCharacters {
  const PaginatedCharacters({
    required this.characters,
    required this.hasNextPage,
    required this.totalCount,
  });

  final List<CharacterModel> characters;
  final bool hasNextPage;
  final int totalCount;
}
