import AsyncStorage from '@react-native-async-storage/async-storage';
import { Responsable, ResponsableModel } from '../models/Responsable';
import { Mascota, MascotaModel } from '../models/Mascota';
import { Planilla, PlanillaModel } from '../models/Planilla';

export class LocalStorageService {
    private static readonly RESPONSABLES_KEY = 'responsables';
    private static readonly MASCOTAS_KEY = 'mascotas';
    private static readonly PLANILLAS_KEY = 'planillas';
    private static readonly PENDING_SYNC_KEY = 'pending_sync';

    // Responsables
    static async saveResponsables(responsables: Responsable[]): Promise<void> {
        try {
            const data = responsables.map(r => ResponsableModel.toJson(r));
            await AsyncStorage.setItem(this.RESPONSABLES_KEY, JSON.stringify(data));
        } catch (error) {
            console.error('Error guardando responsables:', error);
        }
    }

    static async getResponsables(): Promise<Responsable[]> {
        try {
            const data = await AsyncStorage.getItem(this.RESPONSABLES_KEY);
            if (data) {
                const jsonData = JSON.parse(data);
                return jsonData.map((r: any) => ResponsableModel.fromJson(r));
            }
            return [];
        } catch (error) {
            console.error('Error obteniendo responsables:', error);
            return [];
        }
    }

    static async addResponsable(responsable: Responsable): Promise<void> {
        try {
            const responsables = await this.getResponsables();
            responsables.push(responsable);
            await this.saveResponsables(responsables);
        } catch (error) {
            console.error('Error agregando responsable:', error);
        }
    }

    // Mascotas
    static async saveMascotas(mascotas: Mascota[]): Promise<void> {
        try {
            const data = mascotas.map(m => MascotaModel.toJson(m));
            await AsyncStorage.setItem(this.MASCOTAS_KEY, JSON.stringify(data));
        } catch (error) {
            console.error('Error guardando mascotas:', error);
        }
    }

    static async getMascotas(): Promise<Mascota[]> {
        try {
            const data = await AsyncStorage.getItem(this.MASCOTAS_KEY);
            if (data) {
                const jsonData = JSON.parse(data);
                return jsonData.map((m: any) => MascotaModel.fromJson(m));
            }
            return [];
        } catch (error) {
            console.error('Error obteniendo mascotas:', error);
            return [];
        }
    }

    static async addMascota(mascota: Mascota): Promise<void> {
        try {
            const mascotas = await this.getMascotas();
            mascotas.push(mascota);
            await this.saveMascotas(mascotas);
        } catch (error) {
            console.error('Error agregando mascota:', error);
        }
    }

    // Planillas
    static async savePlanillas(planillas: Planilla[]): Promise<void> {
        try {
            const data = planillas.map(p => PlanillaModel.toJson(p));
            await AsyncStorage.setItem(this.PLANILLAS_KEY, JSON.stringify(data));
        } catch (error) {
            console.error('Error guardando planillas:', error);
        }
    }

    static async getPlanillas(): Promise<Planilla[]> {
        try {
            const data = await AsyncStorage.getItem(this.PLANILLAS_KEY);
            if (data) {
                const jsonData = JSON.parse(data);
                return jsonData.map((p: any) => PlanillaModel.fromJson(p));
            }
            return [];
        } catch (error) {
            console.error('Error obteniendo planillas:', error);
            return [];
        }
    }

    static async addPlanilla(planilla: Planilla): Promise<void> {
        try {
            const planillas = await this.getPlanillas();
            planillas.push(planilla);
            await this.savePlanillas(planillas);
        } catch (error) {
            console.error('Error agregando planilla:', error);
        }
    }

    // Sincronización pendiente
    static async addPendingSync(item: any): Promise<void> {
        try {
            const pending = await this.getPendingSync();
            pending.push(item);
            await AsyncStorage.setItem(this.PENDING_SYNC_KEY, JSON.stringify(pending));
        } catch (error) {
            console.error('Error agregando sincronización pendiente:', error);
        }
    }

    static async getPendingSync(): Promise<any[]> {
        try {
            const data = await AsyncStorage.getItem(this.PENDING_SYNC_KEY);
            return data ? JSON.parse(data) : [];
        } catch (error) {
            console.error('Error obteniendo sincronización pendiente:', error);
            return [];
        }
    }

    static async clearPendingSync(): Promise<void> {
        try {
            await AsyncStorage.removeItem(this.PENDING_SYNC_KEY);
        } catch (error) {
            console.error('Error limpiando sincronización pendiente:', error);
        }
    }
} 