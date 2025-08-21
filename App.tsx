import React, { useEffect, useState } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { View, Text, ActivityIndicator, StyleSheet } from 'react-native';
import { AuthService } from './src/services/AuthService';
import { LoginScreen } from './src/screens/LoginScreen';
import { HomeScreen } from './src/screens/HomeScreen';
import { PlanillaListScreen } from './src/screens/PlanillaListScreen';

const Stack = createStackNavigator();

const SplashScreen = () => (
    <View style={styles.splashContainer}>
        <Text style={styles.splashIcon}>🐾</Text>
        <Text style={styles.splashTitle}>Veterinario</Text>
        <ActivityIndicator size="large" color="#008080" style={styles.loader} />
    </View>
);

export default function App() {
    const [isLoading, setIsLoading] = useState(true);
    const [isLoggedIn, setIsLoggedIn] = useState(false);

    useEffect(() => {
        checkLoginStatus();
    }, []);

    const checkLoginStatus = async () => {
        try {
            const loggedIn = await AuthService.isLoggedIn();
            setIsLoggedIn(loggedIn);
        } catch (error) {
            console.error('Error checking login status:', error);
        } finally {
            setIsLoading(false);
        }
    };

    if (isLoading) {
        return <SplashScreen />;
    }

    return (
        <NavigationContainer>
            <Stack.Navigator
                screenOptions={{
                    headerShown: false,
                }}
            >
                {isLoggedIn ? (
                    <>
                        <Stack.Screen name="Home" component={HomeScreen} />
                        <Stack.Screen name="PlanillaList" component={PlanillaListScreen} />
                    </>
                ) : (
                    <Stack.Screen name="Login" component={LoginScreen} />
                )}
            </Stack.Navigator>
        </NavigationContainer>
    );
}

const styles = StyleSheet.create({
    splashContainer: {
        flex: 1,
        backgroundColor: '#008080',
        justifyContent: 'center',
        alignItems: 'center',
    },
    splashIcon: {
        fontSize: 80,
        marginBottom: 16,
    },
    splashTitle: {
        fontSize: 24,
        fontWeight: 'bold',
        color: 'white',
        marginBottom: 32,
    },
    loader: {
        marginTop: 20,
    },
}); 