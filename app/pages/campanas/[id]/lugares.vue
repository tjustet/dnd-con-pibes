<script setup>
// IMPORTACIÓN ESTRICTA: Saltamos un nivel hacia atrás para salir de 'pages' y entrar a 'components'
import GestorCiudades from '../../components/dm/GestorCiudades.vue'
</script>

<template>
  <div class="pantalla-lugares-raiz">
    <div class="filtro-fondo-oscuro"></div>
    
    <div class="contenido-lugares-layout">
      <GestorCiudades />
    </div>
  </div>
</template>

<style scoped>
.pantalla-lugares-raiz {
  min-height: 100vh;
  background-color: #050505;
  color: #cbd5e1;
  position: relative;
  overflow-x: hidden;
}

.filtro-fondo-oscuro {
  position: absolute;
  inset: 0;
  background: radial-gradient(circle at center, #18181b 0%, #000 100%);
  z-index: 0;
}

.contenido-lugares-layout {
  position: relative;
  z-index: 10;
  max-width: 1650px;
  margin: 0 auto;
}
</style>