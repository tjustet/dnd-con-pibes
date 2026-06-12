<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'

const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()

const cargando = ref(true)
const campana = ref({ nombre: 'Cargando Mesa del DM...' })

// ==========================================
// ESTADO PERSISTENTE Y REALTIME
// ==========================================
const estadoMesa = ref({ pjs: [], npcs: [], enemigos: [], entidadVisible: null })
const historialCompartido = ref([]) 
let canalMesa = null 
let canalPersonajes = null // NUEVO: Canal para escuchar la vida de los PJs

const todosLosPjsDeCampana = ref([])
const npcsDisponibles = ref([])
const enemigosDisponibles = ref([])

const filtroPj = ref('')
const filtroNpc = ref({ nombre: '', dificultad: '' })
const filtroEnemigo = ref({ nombre: '', dificultad: '' })

const personajesActivos = computed(() => estadoMesa.value.pjs.map(id => todosLosPjsDeCampana.value.find(p => p.id === id)).filter(Boolean))
const npcsActivos = computed(() => estadoMesa.value.npcs)
const enemigosActivos = computed(() => estadoMesa.value.enemigos)

const jugadoresIzquierda = computed(() => personajesActivos.value.slice(0, 3))
const jugadoresDerecha = computed(() => personajesActivos.value.slice(3, 5))
const jugadoresSuperiores = computed(() => personajesActivos.value.slice(5))
const todasLasEntidadesActivas = computed(() => [...personajesActivos.value, ...npcsActivos.value, ...enemigosActivos.value])

const drawerAbierto = ref(false)
const drawerLado = ref('left')
const entidadActiva = ref(null)
const tipoEntidadActiva = ref('')
const filtroAtaquesDrawer = ref('')
const tooltipActivo = ref(null) // NUEVO: Controla qué input de HP muestra el cartelito

const modalAgregarJugadorAbierto = ref(false)
const modalAgregarNpcAbierto = ref(false)
const modalAgregarEnemigoAbierto = ref(false)
const modalIniciativaAbierto = ref(false)

const dadosOcultos = ref(false)
const dmPool = ref([])
const dmBono = ref(0)
const dmTirando = ref(false)
const dmDadosEnMesa = ref([])
const dmResultadoFinal = ref(0)

const combateActivo = ref(false)
const ordenIniciativa = ref([])
const turnoActual = ref(0)
const seleccionIniciativa = ref([])

const calcMod = (val) => Math.floor((val - 10) / 2)
const calcModStr = (val) => { const m = calcMod(val); return m >= 0 ? `+${m}` : `${m}` }

// ------------------------------------------
// PERSISTENCIA DE MESA Y DADOS
// ------------------------------------------
let saveTimeout = null
const guardarMesaDb = async () => {
  clearTimeout(saveTimeout)
  saveTimeout = setTimeout(async () => {
    await supabase.from('campaigns').update({ mesa_estado: estadoMesa.value }).eq('id', route.params.id)
  }, 1000)
}
const guardarHistorialDb = async (nuevoHistorial) => {
  await supabase.from('campaigns').update({ historial_dados: nuevoHistorial }).eq('id', route.params.id)
}

// ------------------------------------------
// LÓGICA DE DADOS
// ------------------------------------------
const agregarDadoDm = (caras) => dmPool.value.push(caras)
const limpiarPoolDm = () => { dmPool.value = []; dmBono.value = 0; dmDadosEnMesa.value = []; dmResultadoFinal.value = 0 }

const tirarPoolDm = (tituloPerso = null) => {
  if (dmPool.value.length === 0) return
  dmTirando.value = true
  dmResultadoFinal.value = 0
  const arrayDeCaras = [...dmPool.value]
  const bonoNum = parseInt(dmBono.value) || 0

  const intervalo = setInterval(() => { dmDadosEnMesa.value = arrayDeCaras.map(c => ({ caras: c, valor: Math.floor(Math.random() * c) + 1 })) }, 100)

  setTimeout(() => {
    clearInterval(intervalo)
    let suma = 0
    dmDadosEnMesa.value = arrayDeCaras.map(c => { const v = Math.floor(Math.random() * c) + 1; suma += v; return { caras: c, valor: v } })
    dmResultadoFinal.value = suma + bonoNum
    dmTirando.value = false

    const nuevaTirada = {
      id: Date.now(),
      tirador: 'DM',
      titulo: tituloPerso || 'Tirada del DM',
      dadosStr: dmDadosEnMesa.value.map(d => `d${d.caras}[${d.valor}]`).join(', '),
      bono: bonoNum,
      total: dmResultadoFinal.value,
      oculto: dadosOcultos.value,
      targetAsignado: '',
      mostrarAsignador: false
    }

    const nuevoHist = [nuevaTirada, ...historialCompartido.value].slice(0, 30)
    historialCompartido.value = nuevoHist
    guardarHistorialDb(nuevoHist)
  }, 1200)
}

const tirarDesdeDrawer = (titulo, caras, bono) => {
  limpiarPoolDm()
  if (Array.isArray(caras)) caras.forEach(c => agregarDadoDm(c))
  else agregarDadoDm(caras)
  dmBono.value = bono || 0
  tirarPoolDm(`${entidadActiva.value.nombre_pj}: ${titulo}`)
}

const tirarAtaque = (atk) => tirarDesdeDrawer(`Ataca con ${atk.nombre}`, 20, atk.bono)
const tirarDano = (atk) => { const dados = Array(atk.cant_dados).fill(atk.tipo_dado); tirarDesdeDrawer(`Daño de ${atk.nombre}`, dados, atk.bono_dano) }
const tirarStat = (nombre, valor) => tirarDesdeDrawer(`Chequeo de ${nombre}`, 20, calcMod(valor))

// ------------------------------------------
// DAÑO Y CURACIÓN
// ------------------------------------------
const aplicarDano = (registro) => { if (registro.targetAsignado) { procesarHp(registro.targetAsignado, -registro.total); registro.mostrarAsignador = false } }
const curarDano = (registro) => { if (registro.targetAsignado) { procesarHp(registro.targetAsignado, registro.total); registro.mostrarAsignador = false } }

const procesarHp = (instanceId, cantidad) => {
  const pj = personajesActivos.value.find(p => p.id === instanceId)
  if (pj) {
    pj.hp_actual = Math.max(0, Math.min(pj.hp_max, pj.hp_actual + cantidad))
    supabase.from('characters').update({ hp_actual: pj.hp_actual }).eq('id', pj.id).then()
    return
  }
  const npc = estadoMesa.value.npcs.find(n => n.instance_id === instanceId)
  if (npc) { npc.hp_actual = Math.max(0, Math.min(npc.hp_max, npc.hp_actual + cantidad)); guardarMesaDb(); return }
  
  const en = estadoMesa.value.enemigos.find(e => e.instance_id === instanceId)
  if (en) { en.hp_actual = Math.max(0, Math.min(en.hp_max, en.hp_actual + cantidad)); guardarMesaDb() }
}

// ------------------------------------------
// TOOLTIP Y ACTUALIZACIÓN MANUAL DE HP
// ------------------------------------------
const guardarHpYQuitarFoco = (event, entidad, tipo) => {
  entidad.hp_actual = Math.max(0, Math.min(entidad.hp_max, entidad.hp_actual))
  if (tipo === 'pj') {
    supabase.from('characters').update({ hp_actual: entidad.hp_actual }).eq('id', entidad.id).then()
  } else {
    guardarMesaDb()
  }
  event.target.blur() // Quita el foco del input y esconde el tooltip
}

// ------------------------------------------
// REVELAR A JUGADORES
// ------------------------------------------
const mostrarAJugadores = (entidad) => { estadoMesa.value.entidadVisible = { nombre: entidad.nombre_pj, imagen: entidad.imagen_url || '' }; guardarMesaDb() }
const limpiarVisionJugadores = () => { estadoMesa.value.entidadVisible = null; guardarMesaDb() }

// ------------------------------------------
// CARGA, CONTROL Y WEBSOCKETS (REALTIME)
// ------------------------------------------
const cargarMesaDM = async () => {
  cargando.value = true
  const { data: cData } = await supabase.from('campaigns').select('*').eq('id', route.params.id).single()
  if (cData) {
    campana.value = cData
    if (cData.mesa_estado) estadoMesa.value = cData.mesa_estado
    if (cData.historial_dados) historialCompartido.value = cData.historial_dados
  }

  const { data: pData } = await supabase.from('characters').select('*').eq('campaign_id', route.params.id)
  if (pData) {
    const parsedData = pData.map(p => { try { p.ataques = p.ataques || [] } catch { p.ataques = [] }; return p })
    todosLosPjsDeCampana.value = parsedData.filter(p => p.tipo === 'pj' || !p.tipo)
    npcsDisponibles.value = parsedData.filter(p => p.tipo === 'npc')
    enemigosDisponibles.value = parsedData.filter(p => p.tipo === 'enemigo')
  }

  // 1. SUSCRIPCIÓN A LA MESA (Dados y Vision compartida)
  canalMesa = supabase.channel('mesa_compartida')
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'campaigns', filter: `id=eq.${route.params.id}` }, (payload) => {
      if (payload.new.historial_dados) historialCompartido.value = payload.new.historial_dados
    }).subscribe()

  // 2. SUSCRIPCIÓN A LOS PERSONAJES (Vida sincronizada)
  canalPersonajes = supabase.channel('personajes_realtime')
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'characters', filter: `campaign_id=eq.${route.params.id}` }, (payload) => {
      const pjIndex = todosLosPjsDeCampana.value.findIndex(p => p.id === payload.new.id)
      if (pjIndex !== -1) {
        todosLosPjsDeCampana.value[pjIndex].hp_actual = payload.new.hp_actual
      }
    }).subscribe()

  cargando.value = false
}

onUnmounted(() => {
  if (canalMesa) supabase.removeChannel(canalMesa)
  if (canalPersonajes) supabase.removeChannel(canalPersonajes)
})

const pjsFiltrados = computed(() => todosLosPjsDeCampana.value.filter(p => p.nombre_pj.toLowerCase().includes(filtroPj.value.toLowerCase())))
const npcsFiltrados = computed(() => npcsDisponibles.value.filter(n => n.nombre_pj.toLowerCase().includes(filtroNpc.value.nombre.toLowerCase()) && (filtroNpc.value.dificultad === '' || n.dificultad == filtroNpc.value.dificultad)))
const enemigosFiltrados = computed(() => enemigosDisponibles.value.filter(e => e.nombre_pj.toLowerCase().includes(filtroEnemigo.value.nombre.toLowerCase()) && (filtroEnemigo.value.dificultad === '' || e.dificultad == filtroEnemigo.value.dificultad)))
const ataquesFiltradosDrawer = computed(() => { if (!entidadActiva.value || !entidadActiva.value.ataques) return []; return entidadActiva.value.ataques.filter(a => a.nombre.toLowerCase().includes(filtroAtaquesDrawer.value.toLowerCase())) })

const agregarAlTablero = (entidad, tipo) => {
  if (tipo === 'pj' && !estadoMesa.value.pjs.includes(entidad.id)) estadoMesa.value.pjs.push(entidad.id)
  else if (tipo === 'npc') estadoMesa.value.npcs.push({ ...entidad, instance_id: 'npc_' + Date.now(), base_id: entidad.id })
  else if (tipo === 'enemigo') estadoMesa.value.enemigos.push({ ...entidad, instance_id: 'en_' + Date.now(), base_id: entidad.id })
  guardarMesaDb(); modalAgregarJugadorAbierto.value = false; modalAgregarNpcAbierto.value = false; modalAgregarEnemigoAbierto.value = false
}
const desvincular = (idUnico, tipo) => {
  if (tipo === 'pj') estadoMesa.value.pjs = estadoMesa.value.pjs.filter(id => id !== idUnico)
  if (tipo === 'npc') estadoMesa.value.npcs = estadoMesa.value.npcs.filter(n => n.instance_id !== idUnico)
  if (tipo === 'enemigo') estadoMesa.value.enemigos = estadoMesa.value.enemigos.filter(e => e.instance_id !== idUnico)
  guardarMesaDb(); if (entidadActiva.value?.id === idUnico || entidadActiva.value?.instance_id === idUnico) drawerAbierto.value = false
}

const abrirDrawer = (entidad, tipo, lado) => { entidadActiva.value = entidad; tipoEntidadActiva.value = tipo; drawerLado.value = lado; filtroAtaquesDrawer.value = ''; drawerAbierto.value = true }
const abrirFichaNuevaPestana = () => { window.open(`/personajes/${entidadActiva.value.base_id || entidadActiva.value.id}`, '_blank') }

const prepararIniciativa = () => { seleccionIniciativa.value = todasLasEntidadesActivas.value.map(e => e.instance_id || e.id); modalIniciativaAbierto.value = true }
const lanzarIniciativaGlobal = () => {
  const combatientes = todasLasEntidadesActivas.value.filter(e => seleccionIniciativa.value.includes(e.instance_id || e.id))
  ordenIniciativa.value = combatientes.map(c => {
    const d20 = Math.floor(Math.random() * 20) + 1; const modDex = calcMod(c.destreza)
    return { unique_id: c.instance_id || c.id, nombre: c.nombre_pj, imagen: c.imagen_url, total: d20 + modDex, hp_actual: c.hp_actual, hp_max: c.hp_max }
  }).sort((a, b) => b.total - a.total)
  turnoActual.value = 0; combateActivo.value = true; modalIniciativaAbierto.value = false
}
const siguienteTurno = () => { turnoActual.value = (turnoActual.value + 1) % ordenIniciativa.value.length }
const terminarCombate = () => { combateActivo.value = false; ordenIniciativa.value = [] }

const todosEfectos = ref([])
const efectoAInsertar = ref(null)

// En cargarMesaDM() sumá esto:
const { data: efData } = await supabase.from('efectos').select('*').order('nombre')
if (efData) todosEfectos.value = efData

// Funciones para gestionar efectos:
const agregarEfectoManual = (entidad, tipo) => {
  if (!efectoAInsertar.value) return
  // Asegurarse de que exista el array
  if (!entidad.efectos) entidad.efectos = []
  
  // Evitar duplicados
  if (!entidad.efectos.some(e => e.id === efectoAInsertar.value.id)) {
    entidad.efectos.push(efectoAInsertar.value)
    
    if (tipo === 'pj') {
      supabase.from('characters').update({ efectos: entidad.efectos }).eq('id', entidad.id).then()
    } else {
      guardarMesaDb()
    }
  }
  efectoAInsertar.value = null // Resetea el select
}

const quitarEfectoManual = (entidad, tipo, idEfecto) => {
  entidad.efectos = entidad.efectos.filter(e => e.id !== idEfecto)
  if (tipo === 'pj') {
    supabase.from('characters').update({ efectos: entidad.efectos }).eq('id', entidad.id).then()
  } else {
    guardarMesaDb()
  }
}

// Para aplicar un efecto que vino desde un ataque en el historial (Ej: Flecha envenenada)
const aplicarEfectoDesdeHistorial = (registro) => {
  if (!registro.targetAsignado || !registro.efecto_vinculado) return
  
  const targetId = registro.targetAsignado
  // Buscamos a la víctima
  const pj = personajesActivos.value.find(p => p.id === targetId)
  if (pj) { agregarEfectoDesdeObj(pj, 'pj', registro.efecto_vinculado); return }
  
  const npc = estadoMesa.value.npcs.find(n => n.instance_id === targetId)
  if (npc) { agregarEfectoDesdeObj(npc, 'npc', registro.efecto_vinculado); return }
  
  const en = estadoMesa.value.enemigos.find(e => e.instance_id === targetId)
  if (en) { agregarEfectoDesdeObj(en, 'enemigo', registro.efecto_vinculado) }
}

// Función helper para no repetir código
const agregarEfectoDesdeObj = (entidad, tipo, objEfecto) => {
  if (!entidad.efectos) entidad.efectos = []
  if (!entidad.efectos.some(e => e.id === objEfecto.id)) {
    entidad.efectos.push(objEfecto)
    if (tipo === 'pj') supabase.from('characters').update({ efectos: entidad.efectos }).eq('id', entidad.id).then()
    else guardarMesaDb()
  }
}

const limpiarHistorialGlobal = async () => {
  if(confirm("¿Estás seguro de querer borrar todo el registro de dados de esta sesión?")) {
    historialCompartido.value = [] // Lo borramos de la vista
    await supabase.from('campaigns').update({ historial_dados: [] }).eq('id', route.params.id)
  }
}

onMounted(() => { cargarMesaDM() })
</script>

<template>
  <div class="mesa-dm-pantalla" :class="{'drawer-open': drawerAbierto}">
    <div class="filtro-oscuro"></div>
    <div v-if="cargando" class="cargando">Abriendo grimorio de campaña...</div>
    <div v-else class="layout-dm">
      
      <div class="panel-superior">
        <div class="header-izq">
          <button @click="router.push(`/campanas/${route.params.id}`)" class="btn-ghost">← Salir</button>
          <h1 class="titulo-dm">Mesa del DM: <span class="campana-name">{{ campana.nombre }}</span></h1>
          <div class="toggle-oculto">
            <span class="lbl-oculto">Ocultar Dados</span>
            <label class="switch"><input type="checkbox" v-model="dadosOcultos"><span class="slider round"></span></label>
          </div>
          <div v-if="estadoMesa.entidadVisible" class="indicador-vision">
            <span>👁️ Mostrando: <strong>{{ estadoMesa.entidadVisible.nombre }}</strong></span>
            <button @click="limpiarVisionJugadores">✖ Ocultar</button>
          </div>
        </div>
        <div class="botones-dm-acciones">
          <button v-if="!combateActivo" @click="prepararIniciativa" class="btn-accion-dm dorado">⚔️ INICIATIVA</button>
          <button v-else @click="terminarCombate" class="btn-accion-dm rojo">🛑 Fin Combate</button>
          <button @click="modalAgregarJugadorAbierto = true" class="btn-accion-dm azul">+ Añadir PJ</button>
          <button @click="modalAgregarNpcAbierto = true" class="btn-accion-dm verde">+ Añadir NPC</button>
          <button @click="modalAgregarEnemigoAbierto = true" class="btn-accion-dm rojo">+ Añadir Enemigo</button>
        </div>
      </div>

      <div v-if="combateActivo" class="barra-iniciativa">
        <div class="controles-iniciativa"><button @click="siguienteTurno" class="btn-siguiente-turno">Siguiente Turno ➔</button></div>
        <div class="tracker-scroll">
          <div v-for="(combatiente, idx) in ordenIniciativa" :key="combatiente.unique_id" class="combatiente-card" :class="{'es-su-turno': idx === turnoActual}">
            <div class="c-badge">{{ combatiente.total }}</div>
            <img v-if="combatiente.imagen" :src="combatiente.imagen" class="c-avatar" /><div v-else class="c-fallback">👤</div>
            <div class="c-info"><span class="c-nom">{{ combatiente.nombre }}</span></div>
          </div>
        </div>
      </div>

      <div class="tablero-grid">
        <div class="row-superior-pjs" v-if="jugadoresSuperiores.length > 0">
          <div v-for="pj in jugadoresSuperiores" :key="pj.id" class="mini-card-pj" @click="abrirDrawer(pj, 'pj', 'right')">
            <button class="btn-sacar-tablero" @click.stop="desvincular(pj.id, 'pj')">✖</button>
            <img v-if="pj.imagen_url" :src="pj.imagen_url" class="card-avatar" /><div v-else class="card-fallback">🛡️</div>
            <div class="card-info">
              <h3>{{ pj.nombre_pj }}</h3>
              <div class="hp-direct-box relative" @click.stop>
                <span v-if="tooltipActivo === pj.id" class="hp-tooltip">↵ Enter para guardar</span>
                <input type="number" v-model="pj.hp_actual" @focus="tooltipActivo = pj.id" @blur="tooltipActivo = null" @keyup.enter="guardarHpYQuitarFoco($event, pj, 'pj')" class="input-hp-rapido"/>
                <span>/ {{ pj.hp_max }}</span>
              </div>
            </div>
          </div>
        </div>

        <div class="cuerpo-tablero">
          <div class="columna-pjs">
            <h4 class="col-titulo">Grupo (Izq)</h4>
            <div v-for="pj in jugadoresIzquierda" :key="pj.id" class="mini-card-pj" @click="abrirDrawer(pj, 'pj', 'left')">
              <button class="btn-sacar-tablero" @click.stop="desvincular(pj.id, 'pj')">✖</button>
              <img v-if="pj.imagen_url" :src="pj.imagen_url" class="card-avatar" /><div v-else class="card-fallback">🛡️</div>
              <div class="card-info">
                <h3>{{ pj.nombre_pj }}</h3>
                <div class="hp-bar-container"><div class="hp-bar-fill" :style="{width: (pj.hp_actual/pj.hp_max)*100 + '%'}"></div></div>
                <div class="hp-direct-box relative" @click.stop>
                  <span v-if="tooltipActivo === pj.id" class="hp-tooltip">↵ Enter</span>
                  <input type="number" v-model="pj.hp_actual" @focus="tooltipActivo = pj.id" @blur="tooltipActivo = null" @keyup.enter="guardarHpYQuitarFoco($event, pj, 'pj')" class="input-hp-rapido"/>
                  <span>/ {{ pj.hp_max }}</span>
                </div>
                <div class="efectos-mini" v-if="pj.efectos && pj.efectos.length > 0">
                  <span v-for="e in pj.efectos" :key="e.id" :title="e.nombre">{{ e.icono }} {{ e.nombre }}</span>
                </div>
              </div>
            </div>
          </div>

          <div class="centro-dados-dm">
            <div class="mesa-central-fisica">
              <div class="mesa-mitad-izq">
                <div class="header-historial-dm">
                  <h4 class="tit-seccion-mesa" style="margin: 0; border: none;">Registro Global</h4>
                  <button @click="limpiarHistorialGlobal" class="btn-limpiar-historial" title="Borrar historial">🧹</button>
                </div>
                <div class="historial-dm-scroll">
                  <div v-for="h in historialCompartido" :key="h.id" class="hist-item-dm" :class="{'oculto-bg': h.oculto}">
                    <div class="h-header">
                      <span class="h-tirador" :class="{'t-dorado': h.tirador === 'DM'}">{{ h.tirador }}</span>
                      <span v-if="h.oculto" class="ojo-oculto">👁️‍🗨️</span>
                    </div>
                    <div class="h-tit">{{ h.titulo }}</div>
                    <div class="h-datos">{{ h.dadosStr }}</div>
                    <div class="h-body-row"><div class="h-bono">Bono: {{ h.bono >= 0 ? '+' : '' }}{{ h.bono }}</div><div class="h-total">{{ h.total }}</div></div>
                    
                    <button class="btn-toggle-dano" @click="h.mostrarAsignador = !h.mostrarAsignador">🎯 Asignar...</button>
                    <div v-if="h.mostrarAsignador" class="asignador-box">
                      <select v-model="h.targetAsignado" class="select-target">
                        <option value="">Blanco...</option>
                        <option v-for="ent in todasLasEntidadesActivas" :key="ent.instance_id || ent.id" :value="ent.instance_id || ent.id">{{ ent.nombre_pj }}</option>
                      </select>
                      <div class="asignador-acciones" v-if="h.targetAsignado">
                        <button class="btn-asig dmg" @click="aplicarDano(h)">Daño</button>
                        <button class="btn-asig heal" @click="curarDano(h)">Cura</button>
                        <button v-if="h.efecto_vinculado" class="btn-asig veneno" @click="aplicarEfectoDesdeHistorial(h)" :title="h.efecto_vinculado.descripcion">{{ h.efecto_vinculado.icono }} Estado</button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="mesa-mitad-der">
                <div class="tapete-caida-wrap">
                  <div class="tapete-caida"><div v-for="(d, idx) in dmDadosEnMesa" :key="idx" class="dado-dm-3d" :class="{'dado-girando': dmTirando, ['dado-d'+d.caras]: true}">{{ d.valor }}</div></div>
                  <div v-if="!dmTirando && dmResultadoFinal > 0" class="resultado-gigante-dm">{{ dmResultadoFinal }}</div>
                </div>
                <div class="controles-mesa">
                  <div class="fila-botones-dados">
                    <button @click="agregarDadoDm(4)">d4</button><button @click="agregarDadoDm(6)">d6</button><button @click="agregarDadoDm(8)">d8</button>
                    <button @click="agregarDadoDm(10)">d10</button><button @click="agregarDadoDm(12)">d12</button><button @click="agregarDadoDm(20)" class="d20-btn">d20</button><button @click="agregarDadoDm(100)">d100</button>
                  </div>
                  <div class="fila-acciones-mesa">
                    <div class="pool-viewer"><span v-if="dmPool.length === 0" class="pool-vacio">Seleccioná dados...</span><span v-for="(p, i) in dmPool" :key="i" class="pool-badge">d{{ p }}</span></div>
                    <div class="inputs-mesa-final">
                      <input type="number" v-model="dmBono" placeholder="Bono" class="input-bono-dm" />
                      <button class="btn-clear-dm" @click="limpiarPoolDm">✖</button>
                      <button class="btn-roll-dm" @click="tirarPoolDm(null)">ROLL</button>
                    </div>
                  </div>
                </div>
              </div>

            </div>
          </div>

          <div class="columna-pjs">
            <h4 class="col-titulo">Grupo (Der)</h4>
            <div v-for="pj in jugadoresDerecha" :key="pj.id" class="mini-card-pj" @click="abrirDrawer(pj, 'pj', 'right')">
              <button class="btn-sacar-tablero" @click.stop="desvincular(pj.id, 'pj')">✖</button>
              <img v-if="pj.imagen_url" :src="pj.imagen_url" class="card-avatar" /><div v-else class="card-fallback">🛡️</div>
              <div class="card-info">
                <h3>{{ pj.nombre_pj }}</h3>
                <div class="hp-bar-container"><div class="hp-bar-fill" :style="{width: (pj.hp_actual/pj.hp_max)*100 + '%'}"></div></div>
                <div class="hp-direct-box relative" @click.stop>
                  <span v-if="tooltipActivo === pj.id" class="hp-tooltip">↵ Enter</span>
                  <input type="number" v-model="pj.hp_actual" @focus="tooltipActivo = pj.id" @blur="tooltipActivo = null" @keyup.enter="guardarHpYQuitarFoco($event, pj, 'pj')" class="input-hp-rapido"/>
                  <span>/ {{ pj.hp_max }}</span>
                </div>
                <div class="efectos-mini" v-if="pj.efectos && pj.efectos.length > 0">
                  <span v-for="e in pj.efectos" :key="e.id" :title="e.nombre">{{ e.icono }} {{ e.nombre }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="fila-inferior-dm">
          <div class="seccion-tablero-baja verde-borde">
            <h3 class="baja-titulo t-verde">NPCs de la Sesión</h3>
            <div class="lista-baja-cards">
              <div v-for="npc in npcsActivos" :key="npc.instance_id" class="mini-card-pj custom-card" @click="abrirDrawer(npc, 'npc', 'left')">
                <button class="btn-sacar-tablero" @click.stop="desvincular(npc.instance_id, 'npc')">✖</button>
                <img v-if="npc.imagen_url" :src="npc.imagen_url" class="card-avatar" /><div v-else class="card-fallback fallback-npc">👤</div>
                <div class="card-info">
                  <h3>{{ npc.nombre_pj }}</h3>
                  <div class="hp-direct-box relative" @click.stop>
                    <span v-if="tooltipActivo === npc.instance_id" class="hp-tooltip">↵ Enter</span>
                    <input type="number" v-model="npc.hp_actual" @focus="tooltipActivo = npc.instance_id" @blur="tooltipActivo = null" @keyup.enter="guardarHpYQuitarFoco($event, npc, 'npc')" class="input-hp-rapido"/>
                    <span>/ {{ npc.hp_max }}</span>
                  </div>
                  <div class="efectos-mini" v-if="npc.efectos && npc.efectos.length > 0">
                    <span v-for="e in npc.efectos" :key="e.id" :title="e.nombre">{{ e.icono }} {{ e.nombre }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="seccion-tablero-baja rojo-borde">
            <h3 class="baja-titulo t-rojo">Enemigos / Monstruos</h3>
            <div class="lista-baja-cards">
              <div v-for="en in enemigosActivos" :key="en.instance_id" class="mini-card-pj custom-card" @click="abrirDrawer(en, 'enemigo', 'right')">
                <button class="btn-sacar-tablero" @click.stop="desvincular(en.instance_id, 'enemigo')">✖</button>
                <img v-if="en.imagen_url" :src="en.imagen_url" class="card-avatar" /><div v-else class="card-fallback fallback-en">💀</div>
                <div class="card-info">
                  <h3>{{ en.nombre_pj }}</h3>
                  <div class="hp-direct-box relative" @click.stop>
                    <span v-if="tooltipActivo === en.instance_id" class="hp-tooltip">↵ Enter</span>
                    <input type="number" v-model="en.hp_actual" @focus="tooltipActivo = en.instance_id" @blur="tooltipActivo = null" @keyup.enter="guardarHpYQuitarFoco($event, en, 'enemigo')" class="input-hp-rapido"/>
                    <span>/ {{ en.hp_max }}</span>
                  </div>
                  <div class="efectos-mini" v-if="en.efectos && en.efectos.length > 0">
                    <span v-for="e in en.efectos" :key="e.id" :title="e.nombre">{{ e.icono }} {{ e.nombre }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="drawer-overlay" v-if="drawerAbierto" @click="drawerAbierto = false"></div>
    <div class="drawer" :class="drawerLado" v-if="drawerAbierto">
      <button class="btn-cerrar-drawer" @click="drawerAbierto = false">✖</button>
      <div class="drawer-header">
        <img v-if="entidadActiva.imagen_url" :src="entidadActiva.imagen_url" class="drawer-img" /><div v-else class="drawer-fallback">👤</div>
        <div class="drawer-titulos">
          <h2>{{ entidadActiva.nombre_pj }}</h2><span class="badge-drawer">{{ tipoEntidadActiva.toUpperCase() }} | CA: {{ entidadActiva.clase_armadura }} | Vel: {{ entidadActiva.velocidad }}</span>
        </div>
      </div>

      <button class="btn-revelar-vision" @click="mostrarAJugadores(entidadActiva)">👁️ Mostrar Imagen a Jugadores</button>

      <div class="drawer-hp-box relative">
        <label>Puntos de Golpe</label>
        <div class="d-hp-inputs">
          <span v-if="tooltipActivo === 'drawer_hp'" class="hp-tooltip-drawer">↵ Presiona Enter para guardar cambios</span>
          <input type="number" v-model="entidadActiva.hp_actual" @focus="tooltipActivo = 'drawer_hp'" @blur="tooltipActivo = null" @keyup.enter="guardarHpYQuitarFoco($event, entidadActiva, tipoEntidadActiva)" />
          <span>/ {{ entidadActiva.hp_max }}</span>
        </div>
      </div>

      <div class="drawer-seccion-efectos">
        <div class="head-efectos">
          <select v-model="efectoAInsertar" class="select-target short">
            <option :value="null">Añadir condición...</option>
            <option v-for="ef in todosEfectos" :key="ef.id" :value="ef">{{ ef.icono }} {{ ef.nombre }}</option>
          </select>
          <button @click="agregarEfectoManual(entidadActiva, tipoEntidadActiva)" class="btn-asig dmg">Aplicar</button>
        </div>
        
        <div class="tags-efectos">
          <span v-for="e in entidadActiva.efectos" :key="e.id" class="badge-efecto-activo" :title="e.descripcion" @click="quitarEfectoManual(entidadActiva, tipoEntidadActiva, e.id)">
            {{ e.icono }} {{ e.nombre }} ✖
          </span>
          <span v-if="!entidadActiva.efectos || entidadActiva.efectos.length === 0" class="txt-gris">Sano y salvo.</span>
        </div>
      </div>

      <div class="drawer-stats">
        <div class="d-stat" @click="tirarStat('Fuerza', entidadActiva.fuerza)"><label>STR</label><span>{{ entidadActiva.fuerza }} ({{ calcModStr(entidadActiva.fuerza) }})</span></div>
        <div class="d-stat" @click="tirarStat('Destreza', entidadActiva.destreza)"><label>DEX</label><span>{{ entidadActiva.destreza }} ({{ calcModStr(entidadActiva.destreza) }})</span></div>
        <div class="d-stat" @click="tirarStat('Constitución', entidadActiva.constitucion)"><label>CON</label><span>{{ entidadActiva.constitucion }} ({{ calcModStr(entidadActiva.constitucion) }})</span></div>
        <div class="d-stat" @click="tirarStat('Inteligencia', entidadActiva.inteligencia)"><label>INT</label><span>{{ entidadActiva.inteligencia }} ({{ calcModStr(entidadActiva.inteligencia) }})</span></div>
        <div class="d-stat" @click="tirarStat('Sabiduría', entidadActiva.sabiduria)"><label>WIS</label><span>{{ entidadActiva.sabiduria }} ({{ calcModStr(entidadActiva.sabiduria) }})</span></div>
        <div class="d-stat" @click="tirarStat('Carisma', entidadActiva.carisma)"><label>CHA</label><span>{{ entidadActiva.carisma }} ({{ calcModStr(entidadActiva.carisma) }})</span></div>
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
              <button class="btn-roll-hit" @click="tirarAtaque(atk)">🎯 ATQ (+{{ atk.bono }})</button>
              <button class="btn-roll-dmg" @click="tirarDano(atk)">🩸 DAÑO</button>
            </div>
          </div>
        </div>
      </div>
      <button class="btn-full-ficha" @click="abrirFichaNuevaPestana">Abrir Ficha Completa ↗</button>
    </div>

    <div v-if="modalIniciativaAbierto" class="modal-dm-overlay" @click.self="modalIniciativaAbierto = false">
      <div class="modal-dm-sheet form-medium">
        <h3>Llamado a la Batalla (Iniciativa)</h3>
        <div class="lista-vincular check-lista">
          <label v-for="ent in todasLasEntidadesActivas" :key="ent.instance_id || ent.id" class="item-check">
            <input type="checkbox" :value="ent.instance_id || ent.id" v-model="seleccionIniciativa">
            <span :class="{'t-verde': ent.tipo==='npc', 't-rojo': ent.tipo==='enemigo'}">{{ ent.nombre_pj }}</span>
          </label>
        </div>
        <button class="btn-guardar-creacion dorado" @click="lanzarIniciativaGlobal">🎲 TIRAR INICIATIVA</button>
      </div>
    </div>

    <div v-if="modalAgregarJugadorAbierto" class="modal-dm-overlay" @click.self="modalAgregarJugadorAbierto = false">
      <div class="modal-dm-sheet form-medium">
        <h3>Llamar Jugador a la Mesa</h3>
        <input type="text" v-model="filtroPj" placeholder="Buscar héroe..." class="input-search-modal" />
        <div class="lista-vincular-grande">
          <div v-for="p in pjsFiltrados" :key="p.id" class="item-vincular-gigante">
            <img v-if="p.imagen_url" :src="p.imagen_url" class="img-add-grande" />
            <div v-else class="img-add-fallback">🛡️</div>
            <div class="info-add-grande">
              <h4>{{ p.nombre_pj }}</h4>
              <p>{{ p.raza }} {{ p.clase }} (Nvl {{ p.nivel }})</p>
            </div>
            <button class="btn-add-express" @click="agregarAlTablero(p, 'pj')">Añadir</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="modalAgregarNpcAbierto" class="modal-dm-overlay" @click.self="modalAgregarNpcAbierto = false">
      <div class="modal-dm-sheet form-medium">
        <h3>Invocar NPC</h3>
        <div class="filtros-modal-row">
          <input type="text" v-model="filtroNpc.nombre" placeholder="Nombre..." class="input-search-modal" />
          <input type="text" v-model="filtroNpc.dificultad" placeholder="CR" class="input-search-modal corto" />
        </div>
        <div class="lista-vincular-grande">
          <div v-for="n in npcsFiltrados" :key="n.id" class="item-vincular-gigante borde-verde">
            <img v-if="n.imagen_url" :src="n.imagen_url" class="img-add-grande" />
            <div v-else class="img-add-fallback verde">👤</div>
            <div class="info-add-grande">
              <h4>{{ n.nombre_pj }}</h4>
              <p>Clase: {{ n.clase || '-' }} | CR: {{ n.dificultad || '-' }}</p>
            </div>
            <button class="btn-add-express verde" @click="agregarAlTablero(n, 'npc')">Añadir</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="modalAgregarEnemigoAbierto" class="modal-dm-overlay" @click.self="modalAgregarEnemigoAbierto = false">
      <div class="modal-dm-sheet form-medium">
        <h3>Desatar Enemigo</h3>
        <div class="filtros-modal-row">
          <input type="text" v-model="filtroEnemigo.nombre" placeholder="Nombre..." class="input-search-modal" />
          <input type="text" v-model="filtroEnemigo.dificultad" placeholder="CR" class="input-search-modal corto" />
        </div>
        <div class="lista-vincular-grande">
          <div v-for="e in enemigosFiltrados" :key="e.id" class="item-vincular-gigante borde-rojo">
            <img v-if="e.imagen_url" :src="e.imagen_url" class="img-add-grande" />
            <div v-else class="img-add-fallback rojo">💀</div>
            <div class="info-add-grande">
              <h4>{{ e.nombre_pj }}</h4>
              <p>Clase: {{ e.clase || '-' }} | CR: {{ e.dificultad || '-' }}</p>
            </div>
            <button class="btn-add-express rojo" @click="agregarAlTablero(e, 'enemigo')">Añadir</button>
          </div>
        </div>
      </div>
    </div>


    </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Inter:wght@400;600;700&display=swap');
input[type=number]::-webkit-inner-spin-button, input[type=number]::-webkit-outer-spin-button { -webkit-appearance: none; margin: 0; }

.mesa-dm-pantalla { min-height: 100vh; background-color: #050505; color: #cbd5e1; font-family: 'Inter', sans-serif; position: relative; padding: 1rem; overflow-x: hidden; }
.drawer-open { padding-right: 360px; transition: padding 0.3s; } 
.filtro-oscuro { position: absolute; inset: 0; background: radial-gradient(circle at center, #18181b 0%, #000 100%); z-index: 0; }
.layout-dm { position: relative; z-index: 10; max-width: 1650px; margin: 0 auto; display: flex; flex-direction: column; gap: 1rem; transition: 0.3s; }

/* Tooltips */
.relative { position: relative; }
.hp-tooltip { position: absolute; bottom: 120%; left: 50%; transform: translateX(-50%); background: #10b981; color: #022c22; font-weight: bold; font-size: 0.65rem; padding: 0.3rem 0.5rem; border-radius: 4px; white-space: nowrap; z-index: 50; box-shadow: 0 4px 10px rgba(16,185,129,0.3); animation: pop 0.2s; }
.hp-tooltip::after { content: ''; position: absolute; top: 100%; left: 50%; margin-left: -4px; border-width: 4px; border-style: solid; border-color: #10b981 transparent transparent transparent; }
.hp-tooltip-drawer { position: absolute; top: -20px; left: 50%; transform: translateX(-50%); background: #10b981; color: #022c22; font-weight: bold; font-size: 0.7rem; padding: 0.3rem 0.8rem; border-radius: 4px; white-space: nowrap; animation: pop 0.2s; }
@keyframes pop { 0% { opacity: 0; transform: translate(-50%, 5px); } 100% { opacity: 1; transform: translate(-50%, 0); } }


.panel-superior { display: flex; justify-content: space-between; align-items: center; background: #0a0a0c; border: 1px solid #1e293b; padding: 1rem; border-radius: 8px; box-shadow: 0 4px 15px rgba(0,0,0,0.5); }
.header-izq { display: flex; gap: 1.5rem; align-items: center; flex-wrap: wrap; }
.titulo-dm { font-family: 'Cinzel', serif; font-size: 1.6rem; color: #facc15; margin: 0; }
.btn-ghost { background: transparent; border: 1px solid #334155; color: #94a3b8; padding: 0.4rem 0.8rem; border-radius: 4px; cursor: pointer; font-weight: 600; }
.toggle-oculto { display: flex; align-items: center; gap: 0.5rem; background: #111; padding: 0.4rem 0.8rem; border-radius: 6px; border: 1px dashed #334155; }
.lbl-oculto { font-size: 0.8rem; color: #94a3b8; font-weight: bold; }
.switch { position: relative; display: inline-block; width: 40px; height: 20px; }
.switch input { opacity: 0; width: 0; height: 0; }
.slider { position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: #334155; transition: .4s; border-radius: 20px; }
.slider:before { position: absolute; content: ""; height: 14px; width: 14px; left: 3px; bottom: 3px; background-color: white; transition: .4s; border-radius: 50%; }
input:checked + .slider { background-color: #7f1d1d; }
input:checked + .slider:before { transform: translateX(20px); }

.indicador-vision { display: flex; align-items: center; gap: 1rem; background: rgba(59, 130, 246, 0.15); border: 1px solid #3b82f6; padding: 0.4rem 1rem; border-radius: 6px; color: #93c5fd; font-size: 0.85rem; }
.indicador-vision button { background: #1e3a8a; border: none; color: white; border-radius: 4px; padding: 0.2rem 0.5rem; font-size: 0.75rem; cursor: pointer; }
.botones-dm-acciones { display: flex; gap: 0.8rem; flex-wrap: wrap;}
.btn-accion-dm { border: none; color: white; font-family: 'Cinzel', serif; font-weight: bold; padding: 0.5rem 1rem; border-radius: 6px; cursor: pointer; transition: 0.2s; }
.btn-accion-dm.azul { background: #1e3a8a; border: 1px solid #3b82f6; }
.btn-accion-dm.verde { background: #064e3b; border: 1px solid #10b981; }
.btn-accion-dm.rojo { background: #7f1d1d; border: 1px solid #ef4444; }
.btn-accion-dm.dorado { background: #b45309; border: 1px solid #f59e0b; color: white; box-shadow: 0 0 10px rgba(245,158,11,0.3); }

/* TABLERO MAESTRO */
.tablero-grid { display: flex; flex-direction: column; gap: 1.5rem; }
.cuerpo-tablero { display: grid; grid-template-columns: 280px 1fr 280px; gap: 1.5rem; align-items: start; }
.columna-pjs { background: rgba(10,10,12,0.8); border: 1px solid #1e293b; border-radius: 8px; padding: 1rem; display: flex; flex-direction: column; gap: 1rem; min-height: 400px; }
.col-titulo { font-family: 'Cinzel', serif; color: #64748b; margin: 0; border-bottom: 1px solid #1e293b; padding-bottom: 0.3rem; text-align: center; }

.mini-card-pj { background: #111; border: 1px solid #334155; border-radius: 8px; padding: 0.6rem; display: flex; align-items: center; cursor: pointer; transition: 0.2s; position: relative; }
.mini-card-pj:hover { border-color: #3b82f6; background: #141417; transform: translateX(5px); }
.card-avatar { width: 50px; height: 50px; object-fit: cover; border-radius: 6px; margin-right: 0.8rem; border: 1px solid #27272a; }
.card-fallback { width: 50px; height: 50px; background: #050505; border: 1px dashed #334155; border-radius: 6px; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; margin-right: 0.8rem; }
.card-info h3 { margin: 0; font-size: 1rem; color: white; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 130px; }
.btn-sacar-tablero { position: absolute; top: -5px; right: -5px; background: #7f1d1d; color: white; border: none; border-radius: 50%; width: 18px; height: 18px; font-size: 0.6rem; cursor: pointer; display: flex; align-items: center; justify-content: center; opacity: 0; }
.mini-card-pj:hover .btn-sacar-tablero { opacity: 1; }

.hp-bar-container { background: #1e293b; height: 4px; border-radius: 2px; width: 100%; margin-top: 0.3rem; overflow: hidden; }
.hp-bar-fill { height: 100%; background: linear-gradient(90deg, #b91c1c, #ef4444); transition: width 0.3s; }
.hp-direct-box { display: flex; align-items: center; gap: 0.3rem; margin-top: 0.3rem; }
.input-hp-rapido { width: 45px; background: #050505; border: 1px solid #475569; color: #fca5a5; font-weight: bold; text-align: center; border-radius: 4px; padding: 0.2rem; outline: none; transition: border-color 0.2s; }
.input-hp-rapido:focus { border-color: #10b981; }

/* FIX CLAVE: MESA CENTRAL DM CON SCROLL PERFECTO */
.centro-dados-dm { display: flex; justify-content: center; align-items: stretch; height: 100%; }
.mesa-central-fisica { display: flex; width: 100%; height: 450px; background: #0a0a0c; border: 2px solid #3b82f6; border-radius: 12px; box-shadow: inset 0 0 30px rgba(0,0,0,0.8); overflow: hidden; }

/* Historial (Izq) - ARREGLO DE SCROLL INFINITO */
.mesa-mitad-izq { width: 280px; background: #111; border-right: 2px solid #1e293b; display: flex; flex-direction: column; padding: 1rem; height: 100%; }
.tit-seccion-mesa { font-family: 'Cinzel', serif; color: #facc15; margin: 0 0 1rem 0; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; text-align: center; flex-shrink: 0; }
.historial-dm-scroll { flex-grow: 1; height: 0; overflow-y: auto; display: flex; flex-direction: column; gap: 0.8rem; padding-right: 0.5rem; }

.hist-item-dm { background: rgba(30, 41, 59, 0.4); border-left: 3px solid #3b82f6; padding: 0.5rem; border-radius: 4px; display: flex; flex-direction: column; flex-shrink: 0; }
.hist-item-dm.oculto-bg { border-left-color: #64748b; background: rgba(15, 23, 42, 0.6); }
.h-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.2rem; }
.h-tirador { font-size: 0.7rem; font-weight: bold; color: #94a3b8; background: #1e293b; padding: 0.1rem 0.4rem; border-radius: 4px; }
.t-dorado { color: #facc15; background: rgba(250,204,21,0.1); }
.h-tit { font-size: 0.8rem; color: #cbd5e1; font-weight: bold; margin-bottom: 0.2rem;}
.ojo-oculto { font-size: 0.8rem; }
.h-datos { font-family: monospace; color: #94a3b8; font-size: 0.75rem; }
.h-body-row { display: flex; justify-content: space-between; align-items: flex-end; margin-top: 0.3rem; }
.h-bono { color: #93c5fd; font-size: 0.7rem; }
.h-total { color: #facc15; font-family: 'Cinzel', serif; font-size: 1.4rem; font-weight: bold; line-height: 1; }
.btn-toggle-dano { background: transparent; border: 1px dashed #64748b; color: #94a3b8; font-size: 0.7rem; margin-top: 0.5rem; border-radius: 4px; cursor: pointer; padding: 0.2rem; width: 100%;}
.btn-toggle-dano:hover { background: #1e293b; color: white; }
.asignador-box { background: #050505; border: 1px solid #334155; padding: 0.5rem; border-radius: 4px; margin-top: 0.3rem; display: flex; flex-direction: column; gap: 0.4rem; }
.select-target { width: 100%; background: #1e293b; color: white; border: 1px solid #475569; border-radius: 4px; font-size: 0.75rem; padding: 0.2rem; }
.asignador-acciones { display: flex; gap: 0.3rem; }
.btn-asig { flex: 1; font-size: 0.7rem; font-weight: bold; border: none; border-radius: 3px; cursor: pointer; padding: 0.3rem; color: white; }
.btn-asig.dmg { background: #991b1b; } .btn-asig.heal { background: #065f46; }

/* Tapete (Der) */
.mesa-mitad-der { flex-grow: 1; display: flex; flex-direction: column; position: relative; background: radial-gradient(circle at center, #1e293b, #050505); min-width: 0; }
.tapete-caida-wrap { flex-grow: 1; position: relative; display: flex; flex-direction: column; justify-content: center; overflow: hidden; }
.tapete-caida { display: flex; flex-wrap: wrap; align-content: flex-start; justify-content: center; gap: 1rem; padding: 1.5rem; max-height: 280px; overflow-y: auto; }
.dado-dm-3d { width: 70px; height: 70px; background: linear-gradient(135deg, #2563eb, #1e3a8a); color: white; display: flex; align-items: center; justify-content: center; font-family: 'Inter', sans-serif; font-size: 1.8rem; font-weight: bold; box-shadow: inset 0 0 10px rgba(0,0,0,0.8), 0 5px 15px rgba(0,0,0,0.6); }
.dado-d20, .dado-d12, .dado-d100, .dado-d10, .dado-d8 { clip-path: polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%); }
.dado-d6 { border-radius: 8px; }
.dado-d4 { clip-path: polygon(50% 0%, 0% 100%, 100% 100%); align-items: flex-end; padding-bottom: 8px; font-size: 1.4rem; }
.resultado-gigante-dm { position: absolute; bottom: 10px; left: 50%; transform: translateX(-50%); font-family: 'Cinzel', serif; font-size: 3.5rem; color: #facc15; font-weight: bold; text-shadow: 0 0 20px rgba(250,204,21,0.5); background: rgba(0,0,0,0.6); padding: 0 1.5rem; border-radius: 12px; border: 1px solid #334155; }
.controles-mesa { background: #0f172a; border-top: 1px solid #1e293b; padding: 1rem; display: flex; flex-direction: column; gap: 0.8rem; flex-shrink: 0; }
.fila-botones-dados { display: flex; justify-content: center; gap: 0.5rem; flex-wrap: wrap; }
.fila-botones-dados button { background: #1e293b; border: 1px solid #334155; color: white; font-family: 'Cinzel', serif; font-weight: bold; padding: 0.5rem; width: 45px; border-radius: 6px; cursor: pointer; transition: 0.2s; }
.fila-botones-dados button:hover { background: #3b82f6; transform: translateY(-3px); }
.d20-btn { background: #1e3a8a !important; color: #facc15 !important; border-color: #3b82f6 !important; }
.fila-acciones-mesa { display: flex; justify-content: space-between; align-items: center; background: #050505; border: 1px dashed #334155; border-radius: 6px; padding: 0.5rem; }
.pool-viewer { display: flex; gap: 0.4rem; flex-wrap: wrap; flex-grow: 1; }
.pool-badge { background: #1e3a8a; border: 1px solid #3b82f6; color: white; padding: 0.2rem 0.5rem; border-radius: 4px; font-family: monospace; font-size: 0.8rem; font-weight: bold; }
.inputs-mesa-final { display: flex; gap: 0.5rem; }
.input-bono-dm { width: 50px; text-align: center; background: #111; border: 1px solid #475569; color: white; border-radius: 4px; font-weight: bold; }
.btn-clear-dm { background: transparent; border: 1px solid #ef4444; color: #fca5a5; padding: 0.4rem; border-radius: 4px; cursor: pointer; }
.btn-roll-dm { background: #b45309; border: 1px solid #d97706; color: white; font-family: 'Cinzel', serif; font-weight: bold; padding: 0.4rem 1.5rem; border-radius: 4px; cursor: pointer; }

/* DRAWERS LATERALES */
.drawer-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 99998; backdrop-filter: blur(2px); }
.drawer { position: fixed; top: 0; bottom: 0; width: 400px; max-width: 90vw; background: #0a0a0c; border-left: 2px solid #3b82f6; border-right: 2px solid #3b82f6; box-shadow: 0 0 30px rgba(0,0,0,0.9); z-index: 99999; padding: 1.5rem; display: flex; flex-direction: column; gap: 1rem; overflow-y: auto; transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1); }
.drawer.right { right: 0; transform: translateX(0); border-left: 2px solid #3b82f6; border-right: none; }
.drawer.left { left: 0; transform: translateX(0); border-right: 2px solid #3b82f6; border-left: none; }
.btn-cerrar-drawer { position: absolute; top: 15px; right: 15px; background: rgba(239,68,68,0.2); color: #fca5a5; border: 1px solid #ef4444; width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center; cursor: pointer; }
.drawer-header { display: flex; align-items: center; gap: 1rem; border-bottom: 1px solid #1e293b; padding-bottom: 1rem; }
.drawer-img { width: 70px; height: 70px; border-radius: 8px; object-fit: cover; border: 1px solid #334155; }
.drawer-fallback { width: 70px; height: 70px; background: #111; border: 1px dashed #334155; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 2rem; }
.drawer-titulos h2 { font-family: 'Cinzel', serif; color: white; margin: 0 0 0.3rem 0; font-size: 1.4rem; }
.badge-drawer { background: #1e293b; color: #94a3b8; font-size: 0.7rem; padding: 0.2rem 0.5rem; border-radius: 4px; font-weight: bold; }
.btn-revelar-vision { background: rgba(59, 130, 246, 0.1); border: 1px solid #3b82f6; color: #93c5fd; padding: 0.6rem; border-radius: 6px; cursor: pointer; font-weight: bold; transition: 0.2s; }
.btn-revelar-vision:hover { background: #1e3a8a; color: white; }
.drawer-hp-box { background: #111; border: 1px solid #334155; padding: 1rem; border-radius: 8px; display: flex; flex-direction: column; align-items: center; }
.drawer-hp-box label { color: #facc15; font-family: 'Cinzel', serif; font-size: 0.9rem; margin-bottom: 0.5rem; }
.d-hp-inputs { display: flex; align-items: baseline; gap: 0.5rem; }
.d-hp-inputs input { width: 80px; background: transparent; border: none; border-bottom: 2px solid #fca5a5; color: #fca5a5; font-size: 2.5rem; font-family: 'Cinzel', serif; text-align: center; outline: none; }
.d-hp-inputs span { color: #94a3b8; font-size: 1.5rem; font-family: 'Cinzel', serif; }
.drawer-stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; }
.d-stat { background: #141417; border: 1px solid #27272a; border-radius: 6px; padding: 0.5rem; text-align: center; cursor: pointer; transition: 0.2s; }
.d-stat:hover { border-color: #3b82f6; background: rgba(59,130,246,0.1); }
.d-stat label { display: block; font-size: 0.65rem; color: #facc15; font-weight: bold; margin-bottom: 0.2rem; pointer-events: none; }
.d-stat span { font-size: 1rem; color: white; font-weight: bold; pointer-events: none; }

.drawer-seccion { background: #111; border: 1px solid #1e293b; padding: 1rem; border-radius: 8px; }
.drawer-seccion.ataques { flex-grow: 1; display: flex; flex-direction: column; overflow: hidden; }
.drawer-seccion h3 { font-family: 'Cinzel', serif; color: #facc15; font-size: 1rem; margin: 0 0 0.8rem 0; border-bottom: 1px solid #1e293b; padding-bottom: 0.3rem; }
.input-search-drawer { width: 100%; background: #050505; border: 1px solid #334155; color: white; padding: 0.5rem; border-radius: 4px; margin-bottom: 0.8rem; font-size: 0.85rem; outline: none;}
.lista-ataques-drawer { overflow-y: auto; display: flex; flex-direction: column; gap: 0.8rem; padding-right: 0.3rem; }
.atk-card-drawer { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 6px; padding: 0.8rem; }
.atk-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; }
.atk-head h4 { margin: 0; color: white; font-size: 0.9rem; }
.atk-dano-fijo { color: #fca5a5; font-family: monospace; font-size: 0.8rem; background: rgba(220,38,38,0.1); padding: 0.1rem 0.3rem; border-radius: 3px; border: 1px solid #7f1d1d; }
.atk-botones { display: flex; gap: 0.5rem; }
.btn-roll-hit { flex: 1; background: #1e3a8a; color: white; border: 1px solid #3b82f6; padding: 0.4rem; border-radius: 4px; font-weight: bold; font-size: 0.75rem; cursor: pointer; }
.btn-roll-dmg { flex: 1; background: #7f1d1d; color: white; border: 1px solid #ef4444; padding: 0.4rem; border-radius: 4px; font-weight: bold; font-size: 0.75rem; cursor: pointer; }
.btn-full-ficha { background: transparent; border: 1px dashed #64748b; color: #94a3b8; padding: 0.6rem; border-radius: 6px; font-weight: bold; cursor: pointer; text-transform: uppercase; letter-spacing: 1px; }

/* FILA INFERIOR */
.fila-inferior-dm { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; margin-top: 1rem; }
.seccion-tablero-baja { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 8px; padding: 1.2rem; min-height: 250px; }
.seccion-tablero-baja.verde-borde { border-top: 4px solid #10b981; }
.seccion-tablero-baja.rojo-borde { border-top: 4px solid #ef4444; }
.baja-titulo { font-family: 'Cinzel', serif; margin: 0 0 1rem 0; font-size: 1.2rem; }
.lista-baja-cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 0.8rem; }
.fallback-npc { color: #10b981; } .fallback-en { color: #ef4444; }

::-webkit-scrollbar { width: 4px; }
::-webkit-scrollbar-thumb { background: #334155; border-radius: 2px; }

/* MODALES GRANDES */
.modal-dm-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.8); backdrop-filter: blur(5px); display: flex; align-items: center; justify-content: center; z-index: 99999; padding: 1rem; }
.modal-dm-sheet { background: #0a0a0c; border: 2px solid #334155; border-radius: 12px; padding: 2rem; position: relative; max-height: 90vh; overflow-y: auto; }
.form-medium { width: 650px !important; max-width: 100%; }
.modal-dm-sheet h3 { font-family: 'Cinzel', serif; color: #facc15; margin: 0 0 1.5rem 0; font-size: 1.5rem; text-align: center; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem;}

.input-search-modal { width: 100%; background: #111; border: 1px solid #334155; color: white; padding: 0.8rem; border-radius: 6px; margin-bottom: 1rem; outline: none; font-size: 1rem; }
.filtros-modal-row { display: flex; gap: 0.5rem; } .corto { width: 100px; text-align: center; }

.lista-vincular-grande { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; max-height: 450px; overflow-y: auto; padding-right: 0.5rem; }
@media (max-width: 600px) { .lista-vincular-grande { grid-template-columns: 1fr; } }
.item-vincular-gigante { background: #111; border: 1px solid #1e293b; border-radius: 8px; padding: 1rem; display: flex; flex-direction: column; align-items: center; text-align: center; gap: 0.8rem; transition: 0.2s; }
.item-vincular-gigante:hover { border-color: #3b82f6; transform: translateY(-3px); }
.item-vincular-gigante.borde-verde:hover { border-color: #10b981; }
.item-vincular-gigante.borde-rojo:hover { border-color: #ef4444; }

.img-add-grande { width: 80px; height: 80px; border-radius: 50%; object-fit: cover; border: 2px solid #334155; }
.img-add-fallback { width: 80px; height: 80px; border-radius: 50%; background: #050505; border: 2px dashed #334155; display: flex; align-items: center; justify-content: center; font-size: 2.5rem; }
.img-add-fallback.verde { color: #10b981; border-color: #10b981; background: rgba(16,185,129,0.1); }
.img-add-fallback.rojo { color: #ef4444; border-color: #ef4444; background: rgba(239,68,68,0.1); }
.info-add-grande h4 { margin: 0; color: white; font-family: 'Cinzel', serif; font-size: 1.1rem; }
.info-add-grande p { margin: 0; font-size: 0.75rem; color: #94a3b8; font-family: monospace; margin-top: 0.2rem; }
.btn-add-express { width: 100%; background: rgba(59, 130, 246, 0.1); border: 1px solid #3b82f6; color: #93c5fd; padding: 0.5rem; border-radius: 4px; font-weight: bold; cursor: pointer; transition: 0.2s; }
.btn-add-express:hover { background: #3b82f6; color: white; }
.btn-add-express.verde { border-color: #10b981; color: #10b981; background: rgba(16,185,129,0.1); }
.btn-add-express.verde:hover { background: #10b981; color: white; }
.btn-add-express.rojo { border-color: #ef4444; color: #ef4444; background: rgba(239,68,68,0.1); }
.btn-add-express.rojo:hover { background: #ef4444; color: white; }

.drawer-seccion-efectos { background: #111; border: 1px solid #1e293b; padding: 1rem; border-radius: 8px; }
.head-efectos { display: flex; gap: 0.5rem; margin-bottom: 0.8rem; }
.tags-efectos { display: flex; flex-wrap: wrap; gap: 0.4rem; }
.badge-efecto-activo { background: rgba(147, 51, 234, 0.2); border: 1px solid #9333ea; color: #d8b4fe; padding: 0.3rem 0.6rem; border-radius: 20px; font-size: 0.8rem; cursor: pointer; transition: 0.2s; }
.badge-efecto-activo:hover { background: #ef4444; border-color: #991b1b; color: white; }
.btn-asig.veneno { background: #6b21a8; }
.btn-asig.veneno:hover { background: #9333ea; }

/* MODAL INICIATIVA */
.check-lista { display: flex; flex-direction: column; gap: 0.5rem; max-height: 300px; overflow-y: auto; background: #111; padding: 1rem; border-radius: 8px; border: 1px solid #334155; margin-bottom: 1rem; }
.item-check { display: flex; align-items: center; gap: 0.8rem; cursor: pointer; color: white; font-size: 1rem; transition: 0.2s; }
.item-check:hover { background: #1e293b; padding-left: 0.5rem; border-radius: 4px; }
.item-check input { width: 18px; height: 18px; accent-color: #facc15; cursor: pointer; }
.t-verde { color: #10b981; font-weight: 600; }
.t-rojo { color: #ef4444; font-weight: 600; }
.btn-guardar-creacion.dorado { width: 100%; background: #b45309; border: 1px solid #d97706; color: white; padding: 0.8rem; border-radius: 6px; font-weight: bold; font-family: 'Cinzel', serif; font-size: 1.1rem; cursor: pointer; transition: 0.2s; box-shadow: 0 4px 10px rgba(180,83,9,0.3); }
.btn-guardar-creacion.dorado:hover { background: #d97706; transform: translateY(-2px); box-shadow: 0 6px 15px rgba(217,119,6,0.4); }

/* BARRA INICIATIVA (TRACKER) */
.barra-iniciativa { display: flex; align-items: center; gap: 1rem; background: #0f172a; border: 1px solid #1e293b; padding: 0.8rem; border-radius: 8px; margin-bottom: 1rem; box-shadow: inset 0 0 15px rgba(0,0,0,0.8); }
.controles-iniciativa { flex-shrink: 0; padding-right: 1rem; border-right: 1px solid #334155; }
.btn-siguiente-turno { background: #1e3a8a; border: 1px solid #3b82f6; color: white; padding: 0.6rem 1.2rem; border-radius: 6px; font-weight: bold; cursor: pointer; transition: 0.2s; font-family: 'Cinzel', serif; }
.btn-siguiente-turno:hover { background: #2563eb; transform: scale(1.05); box-shadow: 0 0 10px rgba(59,130,246,0.5); }
.tracker-scroll { display: flex; gap: 1rem; overflow-x: auto; padding: 1rem; flex-grow: 1; align-items: center; }
.tracker-scroll::-webkit-scrollbar { height: 6px; }
.tracker-scroll::-webkit-scrollbar-thumb { background: #3b82f6; border-radius: 3px; }

/* CARTAS DE COMBATIENTES */
.combatiente-card { display: flex; flex-direction: column; align-items: center; background: #111; border: 2px solid #334155; border-radius: 8px; padding: 0.6rem; min-width: 90px; position: relative; transition: 0.3s; opacity: 0.5; filter: grayscale(50%); }
.combatiente-card.es-su-turno { border-color: #facc15; opacity: 1; filter: grayscale(0%); transform: scale(1.15); background: #1a1a10; box-shadow: 0 0 20px rgba(250,204,21,0.4); z-index: 10; }
.c-badge { position: absolute; top: -10px; right: -10px; background: #ef4444; color: white; width: 26px; height: 26px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 0.85rem; font-weight: bold; border: 2px solid #0a0a0c; box-shadow: 0 2px 5px rgba(0,0,0,0.5); }
.c-avatar { width: 50px; height: 50px; border-radius: 50%; object-fit: cover; border: 2px solid #475569; margin-bottom: 0.4rem; transition: 0.3s; }
.es-su-turno .c-avatar { border-color: #facc15; box-shadow: 0 0 10px rgba(250,204,21,0.5); }
.c-fallback { width: 50px; height: 50px; border-radius: 50%; background: #1e293b; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; border: 2px solid #475569; margin-bottom: 0.4rem; }
.c-nom { font-size: 0.8rem; color: white; text-align: center; font-weight: bold; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 80px; }

.header-historial-dm { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; margin-bottom: 1rem; flex-shrink: 0; }
.btn-limpiar-historial { background: transparent; border: 1px solid #475569; color: #cbd5e1; border-radius: 4px; padding: 0.2rem 0.5rem; cursor: pointer; transition: 0.2s; font-size: 0.9rem; }
.btn-limpiar-historial:hover { background: #7f1d1d; border-color: #ef4444; }
</style>