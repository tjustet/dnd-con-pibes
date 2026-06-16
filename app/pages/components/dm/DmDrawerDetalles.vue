<script setup>
const props = defineProps({
  drawerLado: String,
  entidadActiva: Object,
  tipoEntidadActiva: String,
  tooltipActivo: [String, Number],
  todosEfectos: Array,
  ataquesFiltradosDrawer: Array
})

// Enlaces bidireccionales para el buscador interno y el selector de efectos
const filtroAtaquesDrawer = defineModel('filtroAtaquesDrawer')
const efectoAInsertar = defineModel('efectoAInsertar')

const emit = defineEmits([
  'cerrar', 'mostrar-jugadores', 'guardar-hp', 'agregar-efecto', 'quitar-efecto', 
  'tirar-stat', 'tirar-ataque', 'tirar-dano', 'abrir-ficha', 'set-tooltip'
])

const calcModStr = (val) => { const m = Math.floor((val - 10) / 2); return m >= 0 ? `+${m}` : `${m}` }
</script>

<template>
  <div class="drawer" :class="drawerLado">
    <button class="btn-cerrar-drawer" @click="emit('cerrar')">✖</button>
    <div class="drawer-header">
      <img v-if="entidadActiva.imagen_url" :src="entidadActiva.imagen_url" class="drawer-img" />
      <div v-else class="drawer-fallback">👤</div>
      <div class="drawer-titulos">
        <h2>{{ entidadActiva.nombre_pj }}</h2>
        <span class="badge-drawer">{{ tipoEntidadActiva.toUpperCase() }} | CA: {{ entidadActiva.clase_armadura }} | Vel: {{ entidadActiva.velocidad }}</span>
      </div>
    </div>

    <button class="btn-revelar-vision" @click="emit('mostrar-jugadores', entidadActiva)">👁️ Mostrar Imagen a Jugadores</button>

    <div class="drawer-hp-box relative">
      <label>Puntos de Golpe</label>
      <div class="d-hp-inputs">
        <span v-if="tooltipActivo === 'drawer_hp'" class="hp-tooltip-drawer">↵ Presiona Enter para guardar</span>
        <input type="number" v-model="entidadActiva.hp_actual" @focus="emit('set-tooltip', 'drawer_hp')" @blur="emit('set-tooltip', null)" @keyup.enter="emit('guardar-hp', $event, entidadActiva, tipoEntidadActiva)" />
        <span>/ {{ entidadActiva.hp_max }}</span>
      </div>
    </div>

    <div class="drawer-seccion-efectos">
      <div class="head-efectos">
        <select v-model="efectoAInsertar" class="select-target short">
          <option :value="null">Añadir condición...</option>
          <option v-for="ef in todosEfectos" :key="ef.id" :value="ef">{{ ef.icono }} {{ ef.nombre }}</option>
        </select>
        <button @click="emit('agregar-efecto', entidadActiva, tipoEntidadActiva)" class="btn-asig dmg">Aplicar</button>
      </div>
      <div class="tags-efectos">
        <span v-for="e in entidadActiva.efectos" :key="e.id" class="badge-efecto-activo" :title="e.descripcion" @click="emit('quitar-efecto', entidadActiva, tipoEntidadActiva, e.id)">
          {{ e.icono }} {{ e.nombre }} ✖
        </span>
        <span v-if="!entidadActiva.efectos || entidadActiva.efectos.length === 0" class="txt-gris">Sano y salvo.</span>
      </div>
    </div>

    <div class="drawer-stats">
      <div class="d-stat" @click="emit('tirar-stat', 'Fuerza', entidadActiva.fuerza)"><label>STR</label><span>{{ entidadActiva.fuerza }} ({{ calcModStr(entidadActiva.fuerza) }})</span></div>
      <div class="d-stat" @click="emit('tirar-stat', 'Destreza', entidadActiva.destreza)"><label>DEX</label><span>{{ entidadActiva.destreza }} ({{ calcModStr(entidadActiva.destreza) }})</span></div>
      <div class="d-stat" @click="emit('tirar-stat', 'Constitución', entidadActiva.constitucion)"><label>CON</label><span>{{ entidadActiva.constitucion }} ({{ calcModStr(entidadActiva.constitucion) }})</span></div>
      <div class="d-stat" @click="emit('tirar-stat', 'Inteligencia', entidadActiva.inteligencia)"><label>INT</label><span>{{ entidadActiva.inteligencia }} ({{ calcModStr(entidadActiva.inteligencia) }})</span></div>
      <div class="d-stat" @click="emit('tirar-stat', 'Sabiduría', entidadActiva.sabiduria)"><label>WIS</label><span>{{ entidadActiva.sabiduria }} ({{ calcModStr(entidadActiva.sabiduria) }})</span></div>
      <div class="d-stat" @click="emit('tirar-stat', 'Carisma', entidadActiva.carisma)"><label>CHA</label><span>{{ entidadActiva.carisma }} ({{ calcModStr(entidadActiva.carisma) }})</span></div>
    </div>

    <div class="drawer-seccion" v-if="tipoEntidadActiva !== 'pj'">
      <p class="txt-chico"><span class="txt-dorado">Vuln:</span> {{ entidadActiva.vulnerabilidades || 'Ninguna' }}</p>
      <p class="txt-chico"><span class="txt-dorado">Inmun:</span> {{ entidadActiva.inmunidades || 'Ninguna' }}</p>
    </div>

    <div class="drawer-seccion ataques">
      <h3>Ataques y Acciones</h3>
      <input type="text" v-model="filtroAtaquesDrawer" placeholder="Buscar ataque..." class="input-search-drawer" />
      <div class="lista-ataques-drawer">
        <div v-for="(atk, idx) in ataquesFiltradosDrawer" :key="idx" class="atk-card-drawer">
          <div class="atk-head"><h4>{{ atk.nombre }}</h4><span class="atk-dano-fijo">{{ atk.cant_dados }}d{{ atk.tipo_dado }} +{{ atk.bono_dano }}</span></div>
          <div class="atk-botones" v-if="tipoEntidadActiva !== 'pj'">
            <button class="btn-roll-hit" @click="emit('tirar-ataque', atk)">🎯 ATQ (+{{ atk.bono }})</button>
            <button class="btn-roll-dmg" @click="emit('tirar-dano', atk)">🩸 DAÑO</button>
          </div>
        </div>
      </div>
    </div>
    <button class="btn-full-ficha" @click="emit('abrir-ficha')">Abrir Ficha Completa ↗</button>
  </div>
</template>