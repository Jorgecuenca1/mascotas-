// lib/screens/statistics_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/responsable_service.dart';

class StatisticsScreen extends StatefulWidget {
  final int? planillaId;
  const StatisticsScreen({Key? key, this.planillaId}) : super(key: key);

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _loading = true;
  String? _userType;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentEntries = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    try {
      _userType = await AuthService.userType;
      
      // Cargar datos guardados localmente
      final pendingData = await LocalStorageService.getPendingResponsables();
      
      // Filtrar por planilla si es técnico
      List<Map<String, dynamic>> filteredData = pendingData;
      if (widget.planillaId != null) {
        filteredData = pendingData
            .where((item) => item['planillaId'] == widget.planillaId)
            .toList();
      }
      
      // Calcular estadísticas
      Map<String, int> vacunadoresCounts = {};
      int totalResponsables = filteredData.length;
      int totalMascotas = 0;
      int perros = 0;
      int gatos = 0;
      int conAntecedente = 0;
      
      for (var responsable in filteredData) {
        // Contar por vacunador (usando el timestamp como proxy del usuario)
        String date = responsable['timestamp']?.split('T')[0] ?? 'Sin fecha';
        vacunadoresCounts[date] = (vacunadoresCounts[date] ?? 0) + 1;
        
        // Contar mascotas
        List<dynamic> mascotas = responsable['mascotas'] ?? [];
        totalMascotas += mascotas.length;
        
        for (var mascota in mascotas) {
          if (mascota['tipo'] == 'perro') perros++;
          if (mascota['tipo'] == 'gato') gatos++;
          if (mascota['antecedente_vacunal'] == true) conAntecedente++;
        }
      }
      
      setState(() {
        _stats = {
          'totalResponsables': totalResponsables,
          'totalMascotas': totalMascotas,
          'perros': perros,
          'gatos': gatos,
          'conAntecedente': conAntecedente,
          'sinAntecedente': totalMascotas - conAntecedente,
          'porDia': vacunadoresCounts,
        };
        _recentEntries = filteredData.take(10).toList();
        _loading = false;
      });
      
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando estadísticas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_userType == 'administrador' 
          ? 'Estadísticas Generales'
          : 'Estadísticas del Municipio'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarjetas de resumen
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Responsables',
                        _stats['totalResponsables']?.toString() ?? '0',
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Mascotas',
                        _stats['totalMascotas']?.toString() ?? '0',
                        Icons.pets,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Perros',
                        _stats['perros']?.toString() ?? '0',
                        Icons.pets,
                        Colors.orange,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Gatos',
                        _stats['gatos']?.toString() ?? '0',
                        Icons.pets,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                
                // Estadísticas de vacunación
                SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estado de Vacunación',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildProgressBar(
                          'Con antecedente',
                          _stats['conAntecedente'] ?? 0,
                          _stats['totalMascotas'] ?? 1,
                          Colors.green,
                        ),
                        SizedBox(height: 8),
                        _buildProgressBar(
                          'Sin antecedente',
                          _stats['sinAntecedente'] ?? 0,
                          _stats['totalMascotas'] ?? 1,
                          Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Actividad por día
                if (_stats['porDia'] != null && (_stats['porDia'] as Map).isNotEmpty) ...[
                  SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actividad por Día',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          ...(_stats['porDia'] as Map<String, int>).entries.map((entry) =>
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key),
                                  Chip(
                                    label: Text('${entry.value} registros'),
                                    backgroundColor: Colors.blue.shade100,
                                  ),
                                ],
                              ),
                            ),
                          ).toList(),
                        ],
                      ),
                    ),
                  ),
                ],
                
                // Últimos registros
                if (_recentEntries.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Últimos Registros',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  ..._recentEntries.map((entry) =>
                    Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.person),
                          backgroundColor: Colors.blue.shade100,
                        ),
                        title: Text(entry['nombre'] ?? 'Sin nombre'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Finca: ${entry['finca'] ?? 'Sin especificar'}'),
                            Text('Mascotas: ${(entry['mascotas'] as List?)?.length ?? 0}'),
                            Text('Fecha: ${entry['timestamp']?.split('T')[0] ?? 'Sin fecha'}'),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ).toList(),
                ],
              ],
            ),
          ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, int value, int total, Color color) {
    double percentage = total > 0 ? value / total : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$value de $total (${(percentage * 100).toStringAsFixed(1)}%)'),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }
}