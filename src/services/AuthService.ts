import AsyncStorage from '@react-native-async-storage/async-storage';

export class AuthService {
    private static readonly USER_KEY = 'user_data';
    private static readonly TOKEN_KEY = 'auth_token';

    static async login(username: string, password: string): Promise<boolean> {
        try {
            // Simulación de login - en producción esto sería una llamada a la API
            if (username === 'admin' && password === 'admin') {
                const userData = {
                    id: 1,
                    username: username,
                    nombre: 'Administrador',
                    role: 'admin'
                };

                await AsyncStorage.setItem(this.USER_KEY, JSON.stringify(userData));
                await AsyncStorage.setItem(this.TOKEN_KEY, 'fake_token_123');
                return true;
            }
            return false;
        } catch (error) {
            console.error('Error en login:', error);
            return false;
        }
    }

    static async logout(): Promise<void> {
        try {
            await AsyncStorage.multiRemove([this.USER_KEY, this.TOKEN_KEY]);
        } catch (error) {
            console.error('Error en logout:', error);
        }
    }

    static async isLoggedIn(): Promise<boolean> {
        try {
            const token = await AsyncStorage.getItem(this.TOKEN_KEY);
            return token !== null;
        } catch (error) {
            console.error('Error verificando login:', error);
            return false;
        }
    }

    static async getUser(): Promise<any> {
        try {
            const userData = await AsyncStorage.getItem(this.USER_KEY);
            return userData ? JSON.parse(userData) : null;
        } catch (error) {
            console.error('Error obteniendo usuario:', error);
            return null;
        }
    }

    static async getToken(): Promise<string | null> {
        try {
            return await AsyncStorage.getItem(this.TOKEN_KEY);
        } catch (error) {
            console.error('Error obteniendo token:', error);
            return null;
        }
    }
} 