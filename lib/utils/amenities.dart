import 'package:flutter/material.dart';

/// Commodités possibles d'un logement.
/// Le code (à gauche) est enregistré dans la colonne `amenities` de Supabase.
class Amenity {
  final String code;
  final String label;
  final IconData icon;
  const Amenity(this.code, this.label, this.icon);
}

const amenities = <Amenity>[
  Amenity('forage', 'Forage', Icons.water_drop_outlined),
  Amenity('camwater', 'Eau Camwater', Icons.water),
  Amenity('compteur_eneo', 'Compteur Eneo personnel', Icons.electric_meter_outlined),
  Amenity('groupe_electrogene', 'Groupe électrogène', Icons.bolt),
  Amenity('douche_interne', 'Douche interne', Icons.shower_outlined),
  Amenity('cuisine_interne', 'Cuisine interne', Icons.kitchen_outlined),
  Amenity('meuble', 'Meublé', Icons.chair_outlined),
  Amenity('carrelage', 'Carrelé', Icons.grid_on),
  Amenity('plafond', 'Plafonné', Icons.roofing),
  Amenity('barriere', 'Barrière / clôture', Icons.fence),
  Amenity('gardien', 'Gardien', Icons.security),
  Amenity('parking', 'Parking', Icons.local_parking),
];

Amenity? amenityByCode(String code) {
  for (final a in amenities) {
    if (a.code == code) return a;
  }
  return null;
}
