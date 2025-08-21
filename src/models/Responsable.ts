import { Mascota, MascotaModel } from './Mascota';

export interface Responsable {
  id: number;
  nombre: string;
  telefono: string;
  finca: string;
  zona: 'vereda' | 'centro poblado' | 'barrio';
  nombreZona: string;
  loteVacuna: string;
  creado: Date;
  mascotas: Mascota[];
}

export class ResponsableModel {
  static readonly opcionesZona = ['vereda', 'centro poblado', 'barrio'] as const;

  static fromJson(json: any): Responsable {
    return {
      id: json.id || 0,
      nombre: json.nombre || '',
      telefono: json.telefono || '',
      finca: json.finca || '',
      zona: json.zona || 'vereda',
      nombreZona: json.nombre_zona || '',
      loteVacuna: json.lote_vacuna || '',
      creado: json.creado ? new Date(json.creado) : new Date(),
      mascotas: (json.mascotas || []).map((m: any) => MascotaModel.fromJson(m)),
    };
  }

  static toJson(responsable: Responsable): any {
    return {
      id: responsable.id,
      nombre: responsable.nombre,
      telefono: responsable.telefono,
      finca: responsable.finca,
      zona: responsable.zona,
      nombre_zona: responsable.nombreZona,
      lote_vacuna: responsable.loteVacuna,
      creado: responsable.creado.toISOString(),
      mascotas: responsable.mascotas.map(m => MascotaModel.toJson(m)),
    };
  }
} 