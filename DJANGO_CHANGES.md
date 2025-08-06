# Cambios necesarios en Django para la nueva estructura

## 1. Nuevos modelos Django

### models.py
```python
from django.db import models

class Planilla(models.Model):
    nombre = models.CharField(max_length=100)
    creada = models.DateTimeField(auto_now_add=True)

class Responsable(models.Model):
    nombre = models.CharField(max_length=100)
    telefono = models.CharField(max_length=20)
    finca = models.CharField(max_length=100)
    planilla = models.ForeignKey(Planilla, on_delete=models.CASCADE, related_name='responsables')
    creado = models.DateTimeField(auto_now_add=True)

class Mascota(models.Model):
    TIPO_CHOICES = [
        ('perro', 'Perro'),
        ('gato', 'Gato'),
    ]
    
    nombre = models.CharField(max_length=100)
    tipo = models.CharField(max_length=10, choices=TIPO_CHOICES)
    raza = models.CharField(max_length=10)  # M, H, PME para perros; M, H para gatos
    color = models.CharField(max_length=50)
    antecedente_vacunal = models.BooleanField(default=False)
    responsable = models.ForeignKey(Responsable, on_delete=models.CASCADE, related_name='mascotas')
    creado = models.DateTimeField(auto_now_add=True)
```

## 2. Serializers

### serializers.py
```python
from rest_framework import serializers
from .models import Planilla, Responsable, Mascota

class MascotaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Mascota
        fields = ['id', 'nombre', 'tipo', 'raza', 'color', 'antecedente_vacunal', 'creado']

class ResponsableSerializer(serializers.ModelSerializer):
    mascotas = MascotaSerializer(many=True, read_only=True)
    
    class Meta:
        model = Responsable
        fields = ['id', 'nombre', 'telefono', 'finca', 'creado', 'mascotas']

class PlanillaSerializer(serializers.ModelSerializer):
    responsables = ResponsableSerializer(many=True, read_only=True)
    
    class Meta:
        model = Planilla
        fields = ['id', 'nombre', 'creada', 'responsables']
```

## 3. Views

### views.py
```python
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import Planilla, Responsable, Mascota
from .serializers import PlanillaSerializer, ResponsableSerializer, MascotaSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def planilla_list(request):
    planillas = Planilla.objects.all()
    serializer = PlanillaSerializer(planillas, many=True)
    return Response(serializer.data)

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def responsable_list(request, planilla_id):
    planilla = get_object_or_404(Planilla, id=planilla_id)
    
    if request.method == 'GET':
        responsables = Responsable.objects.filter(planilla=planilla)
        serializer = ResponsableSerializer(responsables, many=True)
        return Response(serializer.data)
    
    elif request.method == 'POST':
        # Crear responsable con mascotas
        responsable_data = request.data.copy()
        mascotas_data = responsable_data.pop('mascotas', [])
        
        serializer = ResponsableSerializer(data=responsable_data)
        if serializer.is_valid():
            responsable = serializer.save(planilla=planilla)
            
            # Crear mascotas asociadas
            for mascota_data in mascotas_data:
                mascota_data['responsable'] = responsable.id
                mascota_serializer = MascotaSerializer(data=mascota_data)
                if mascota_serializer.is_valid():
                    mascota_serializer.save()
            
            # Retornar responsable con mascotas
            return Response(ResponsableSerializer(responsable).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mascota_create(request, responsable_id):
    responsable = get_object_or_404(Responsable, id=responsable_id)
    
    serializer = MascotaSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save(responsable=responsable)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
```

## 4. URLs

### urls.py
```python
from django.urls import path
from . import views

urlpatterns = [
    path('api/planillas/', views.planilla_list, name='planilla-list'),
    path('api/planillas/<int:planilla_id>/responsables/', views.responsable_list, name='responsable-list'),
    path('api/responsables/<int:responsable_id>/mascotas/', views.mascota_create, name='mascota-create'),
]
```

## 5. Migraciones

Ejecuta las migraciones para crear las nuevas tablas:

```bash
python manage.py makemigrations
python manage.py migrate
```

## 6. Endpoints disponibles

- `GET /api/planillas/` - Lista todas las planillas con sus responsables
- `GET /api/planillas/{id}/responsables/` - Lista responsables de una planilla
- `POST /api/planillas/{id}/responsables/` - Crea responsable con mascotas
- `POST /api/responsables/{id}/mascotas/` - Agrega mascota a responsable

## 7. Ejemplo de datos para POST

### Crear responsable con mascotas:
```json
{
  "nombre": "Juan Pérez",
  "telefono": "3001234567",
  "finca": "Finca El Paraíso",
  "mascotas": [
    {
      "nombre": "Luna",
      "tipo": "perro",
      "raza": "M",
      "color": "Negro",
      "antecedente_vacunal": true
    },
    {
      "nombre": "Mittens",
      "tipo": "gato",
      "raza": "H",
      "color": "Gris",
      "antecedente_vacunal": false
    }
  ]
}
```

## 8. Validaciones adicionales recomendadas

```python
# En models.py, agregar validaciones
def clean(self):
    if self.tipo == 'perro' and self.raza not in ['M', 'H', 'PME']:
        raise ValidationError('Raza inválida para perro')
    elif self.tipo == 'gato' and self.raza not in ['M', 'H']:
        raise ValidationError('Raza inválida para gato')
```

## 9. Configuración CORS (si es necesario)

```python
# settings.py
INSTALLED_APPS = [
    # ...
    'corsheaders',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    # ... otros middleware
]

CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
]
```

¡Con estos cambios, tu backend Django estará listo para trabajar con la nueva estructura de Flutter! 