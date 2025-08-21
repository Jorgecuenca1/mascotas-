import React from 'react';
import {
    View,
    Text,
    TouchableOpacity,
    StyleSheet,
    ScrollView,
    Alert,
} from 'react-native';
import { AuthService } from '../services/AuthService';

interface HomeScreenProps {
    navigation: any;
}

export const HomeScreen: React.FC<HomeScreenProps> = ({ navigation }) => {
    const handleLogout = async () => {
        Alert.alert(
            'Cerrar Sesión',
            '¿Está seguro que desea cerrar sesión?',
            [
                {
                    text: 'Cancelar',
                    style: 'cancel',
                },
                {
                    text: 'Cerrar Sesión',
                    style: 'destructive',
                    onPress: async () => {
                        await AuthService.logout();
                        navigation.replace('Login');
                    },
                },
            ]
        );
    };

    const menuItems = [
        {
            title: 'Planillas',
            subtitle: 'Gestionar planillas de vacunación',
            icon: '📋',
            onPress: () => navigation.navigate('PlanillaList'),
        },
        {
            title: 'Responsables',
            subtitle: 'Gestionar responsables de mascotas',
            icon: '👥',
            onPress: () => navigation.navigate('ResponsableList'),
        },
        {
            title: 'Mascotas',
            subtitle: 'Gestionar mascotas',
            icon: '🐾',
            onPress: () => navigation.navigate('MascotaList'),
        },
        {
            title: 'Sincronizar',
            subtitle: 'Sincronizar datos con el servidor',
            icon: '🔄',
            onPress: () => {
                Alert.alert('Sincronización', 'Función de sincronización en desarrollo');
            },
        },
    ];

    return (
        <View style={styles.container}>
            <View style={styles.header}>
                <Text style={styles.headerTitle}>Veterinario</Text>
                <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
                    <Text style={styles.logoutButtonText}>Cerrar Sesión</Text>
                </TouchableOpacity>
            </View>

            <ScrollView style={styles.content}>
                <Text style={styles.welcomeText}>
                    Bienvenido al Sistema de Gestión Veterinaria
                </Text>

                <View style={styles.menuContainer}>
                    {menuItems.map((item, index) => (
                        <TouchableOpacity
                            key={index}
                            style={styles.menuItem}
                            onPress={item.onPress}
                        >
                            <Text style={styles.menuIcon}>{item.icon}</Text>
                            <View style={styles.menuTextContainer}>
                                <Text style={styles.menuTitle}>{item.title}</Text>
                                <Text style={styles.menuSubtitle}>{item.subtitle}</Text>
                            </View>
                            <Text style={styles.menuArrow}>›</Text>
                        </TouchableOpacity>
                    ))}
                </View>
            </ScrollView>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#f5f5f5',
    },
    header: {
        backgroundColor: '#008080',
        paddingTop: 50,
        paddingBottom: 20,
        paddingHorizontal: 20,
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
    },
    headerTitle: {
        fontSize: 24,
        fontWeight: 'bold',
        color: 'white',
    },
    logoutButton: {
        paddingHorizontal: 15,
        paddingVertical: 8,
        backgroundColor: 'rgba(255, 255, 255, 0.2)',
        borderRadius: 6,
    },
    logoutButtonText: {
        color: 'white',
        fontSize: 14,
        fontWeight: '500',
    },
    content: {
        flex: 1,
        padding: 20,
    },
    welcomeText: {
        fontSize: 18,
        color: '#333',
        textAlign: 'center',
        marginBottom: 30,
        fontWeight: '500',
    },
    menuContainer: {
        backgroundColor: 'white',
        borderRadius: 10,
        overflow: 'hidden',
        shadowColor: '#000',
        shadowOffset: {
            width: 0,
            height: 2,
        },
        shadowOpacity: 0.1,
        shadowRadius: 3.84,
        elevation: 5,
    },
    menuItem: {
        flexDirection: 'row',
        alignItems: 'center',
        padding: 20,
        borderBottomWidth: 1,
        borderBottomColor: '#f0f0f0',
    },
    menuIcon: {
        fontSize: 30,
        marginRight: 15,
    },
    menuTextContainer: {
        flex: 1,
    },
    menuTitle: {
        fontSize: 16,
        fontWeight: '600',
        color: '#333',
        marginBottom: 4,
    },
    menuSubtitle: {
        fontSize: 14,
        color: '#666',
    },
    menuArrow: {
        fontSize: 20,
        color: '#ccc',
        fontWeight: 'bold',
    },
}); 