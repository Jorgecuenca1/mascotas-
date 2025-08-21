import React, { useState, useEffect } from 'react';
import {
    View,
    Text,
    TouchableOpacity,
    StyleSheet,
    FlatList,
    Alert,
    RefreshControl,
} from 'react-native';
import { Planilla, PlanillaModel } from '../models/Planilla';
import { LocalStorageService } from '../services/LocalStorageService';

interface PlanillaListScreenProps {
    navigation: any;
}

export const PlanillaListScreen: React.FC<PlanillaListScreenProps> = ({ navigation }) => {
    const [planillas, setPlanillas] = useState<Planilla[]>([]);
    const [refreshing, setRefreshing] = useState(false);

    useEffect(() => {
        loadPlanillas();
    }, []);

    const loadPlanillas = async () => {
        try {
            const data = await LocalStorageService.getPlanillas();
            setPlanillas(data);
        } catch (error) {
            console.error('Error cargando planillas:', error);
        }
    };

    const onRefresh = async () => {
        setRefreshing(true);
        await loadPlanillas();
        setRefreshing(false);
    };

    const handleAddPlanilla = () => {
        navigation.navigate('AddPlanilla');
    };

    const handlePlanillaPress = (planilla: Planilla) => {
        navigation.navigate('PlanillaDetail', { planilla });
    };

    const handleDeletePlanilla = (planilla: Planilla) => {
        Alert.alert(
            'Eliminar Planilla',
            `¿Está seguro que desea eliminar la planilla "${planilla.nombre}"?`,
            [
                {
                    text: 'Cancelar',
                    style: 'cancel',
                },
                {
                    text: 'Eliminar',
                    style: 'destructive',
                    onPress: async () => {
                        try {
                            const updatedPlanillas = planillas.filter(p => p.id !== planilla.id);
                            await LocalStorageService.savePlanillas(updatedPlanillas);
                            setPlanillas(updatedPlanillas);
                        } catch (error) {
                            Alert.alert('Error', 'No se pudo eliminar la planilla');
                        }
                    },
                },
            ]
        );
    };

    const renderPlanillaItem = ({ item }: { item: Planilla }) => (
        <TouchableOpacity
            style={styles.planillaItem}
            onPress={() => handlePlanillaPress(item)}
            onLongPress={() => handleDeletePlanilla(item)}
        >
            <View style={styles.planillaHeader}>
                <Text style={styles.planillaName}>{item.nombre}</Text>
                <Text style={styles.planillaDate}>
                    {item.fecha.toLocaleDateString()}
                </Text>
            </View>
            <View style={styles.planillaDetails}>
                <Text style={styles.planillaInfo}>
                    Responsable ID: {item.responsableId}
                </Text>
                <Text style={styles.planillaInfo}>
                    Mascotas: {item.mascotas.length}
                </Text>
            </View>
        </TouchableOpacity>
    );

    return (
        <View style={styles.container}>
            <View style={styles.header}>
                <Text style={styles.headerTitle}>Planillas</Text>
                <TouchableOpacity style={styles.addButton} onPress={handleAddPlanilla}>
                    <Text style={styles.addButtonText}>+</Text>
                </TouchableOpacity>
            </View>

            {planillas.length === 0 ? (
                <View style={styles.emptyContainer}>
                    <Text style={styles.emptyIcon}>📋</Text>
                    <Text style={styles.emptyTitle}>No hay planillas</Text>
                    <Text style={styles.emptySubtitle}>
                        Toca el botón + para crear una nueva planilla
                    </Text>
                </View>
            ) : (
                <FlatList
                    data={planillas}
                    renderItem={renderPlanillaItem}
                    keyExtractor={(item) => item.id.toString()}
                    style={styles.list}
                    refreshControl={
                        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
                    }
                />
            )}
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
    addButton: {
        width: 40,
        height: 40,
        borderRadius: 20,
        backgroundColor: 'rgba(255, 255, 255, 0.2)',
        justifyContent: 'center',
        alignItems: 'center',
    },
    addButtonText: {
        fontSize: 24,
        color: 'white',
        fontWeight: 'bold',
    },
    list: {
        flex: 1,
        padding: 20,
    },
    planillaItem: {
        backgroundColor: 'white',
        borderRadius: 10,
        padding: 15,
        marginBottom: 15,
        shadowColor: '#000',
        shadowOffset: {
            width: 0,
            height: 2,
        },
        shadowOpacity: 0.1,
        shadowRadius: 3.84,
        elevation: 5,
    },
    planillaHeader: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: 10,
    },
    planillaName: {
        fontSize: 18,
        fontWeight: '600',
        color: '#333',
        flex: 1,
    },
    planillaDate: {
        fontSize: 14,
        color: '#666',
    },
    planillaDetails: {
        flexDirection: 'row',
        justifyContent: 'space-between',
    },
    planillaInfo: {
        fontSize: 14,
        color: '#666',
    },
    emptyContainer: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
        padding: 20,
    },
    emptyIcon: {
        fontSize: 80,
        marginBottom: 20,
    },
    emptyTitle: {
        fontSize: 20,
        fontWeight: '600',
        color: '#333',
        marginBottom: 10,
    },
    emptySubtitle: {
        fontSize: 16,
        color: '#666',
        textAlign: 'center',
    },
}); 