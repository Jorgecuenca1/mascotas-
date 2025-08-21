export interface Mascota {
  id: number;
  nombre: string;
  tipo: 'perro' | 'gato';
  raza: string;
  color: string;
  antecedenteVacunal: boolean;
  responsableId: number;
  creado: Date;
  foto?: string;
  latitud?: number;
  longitud?: number;
}

export class MascotaModel {
  static getRazasPorTipo(tipo: 'perro' | 'gato'): string[] {
    if (tipo === 'perro') {
      return ['M', 'H', 'PME'];
    } else if (tipo === 'gato') {
      return ['M', 'H'];
    }
    return ['M'];
  }

  static fromJson(json: any): Mascota {
    return {
      id: json.id || 0,
      nombre: json.nombre || '',
      tipo: json.tipo || 'perro',
      raza: json.raza || 'M',
      color: json.color || '',
      antecedenteVacunal: json.antecedente_vacunal || false,
      responsableId: json.responsable_id || 0,
      creado: json.creado ? new Date(json.creado) : new Date(),
      foto: json.foto,
      latitud: json.latitud ? parseFloat(json.latitud) : undefined,
      longitud: json.longitud ? parseFloat(json.longitud) : undefined,
    };
  }

  static toJson(mascota: Mascota): any {
    return {
      id: mascota.id,
      nombre: mascota.nombre,
      tipo: mascota.tipo,
      raza: mascota.raza,
      color: mascota.color,
      antecedente_vacunal: mascota.antecedenteVacunal,
      responsable_id: mascota.responsableId,
      creado: mascota.creado.toISOString(),
      ...(mascota.foto && { foto: mascota.foto }),
      ...(mascota.latitud && { latitud: mascota.latitud }),
      ...(mascota.longitud && { longitud: mascota.longitud }),
    };
  }

  static toJsonForApi(mascota: Mascota): any {
    return {
      nombre: mascota.nombre,
      tipo: mascota.tipo,
      raza: mascota.raza,
      color: mascota.color,
      antecedente_vacunal: mascota.antecedenteVacunal,
      ...(mascota.foto && { foto: mascota.foto }),
      ...(mascota.latitud && { latitud: mascota.latitud }),
      ...(mascota.longitud && { longitud: mascota.longitud }),
    };
  }
} 