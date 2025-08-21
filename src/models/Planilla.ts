export interface Planilla {
    id: number;
    nombre: string;
    fecha: Date;
    responsableId: number;
    mascotas: number[];
}

export class PlanillaModel {
    static fromJson(json: any): Planilla {
        return {
            id: json.id || 0,
            nombre: json.nombre || '',
            fecha: json.fecha ? new Date(json.fecha) : new Date(),
            responsableId: json.responsable_id || 0,
            mascotas: json.mascotas || [],
        };
    }

    static toJson(planilla: Planilla): any {
        return {
            id: planilla.id,
            nombre: planilla.nombre,
            fecha: planilla.fecha.toISOString(),
            responsable_id: planilla.responsableId,
            mascotas: planilla.mascotas,
        };
    }
} 