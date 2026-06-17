<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ModalGeneradorNpc from '../ModalGeneradorNpc.vue'

const supabase = useSupabaseClient()
const route = useRoute()
const router = useRouter()

const tamanos = [
  { id: 'aldea', nombre: 'Aldea (Pequeña)', maxTiendas: 4 },
  { id: 'pueblo', nombre: 'Pueblo (Mediano)', maxTiendas: 10 },
  { id: 'ciudad', nombre: 'Ciudad (Grande)', maxTiendas: 20 },
  { id: 'metropolis', nombre: 'Metrópolis (Masiva)', maxTiendas: 35 }
]

const categoriasTiendas = {
  "Comercio y Artesanía": ["Herrería", "Carpintería", "Sastrería", "Joyería", "Alfarería", "Mercado General"],
  "Magia": ["Alquimia", "Tienda Arcana", "Biblioteca Arcana", "Adivino / Oráculo"],
  "Alimentación y Hospedaje": ["Taberna", "Posada", "Panadería", "Carnicería", "Cervecería / Bodega"],
  "Aventureros": ["Gremio de Aventureros", "Tienda de Suministros", "Cartógrafo", "Casa de Recompensas", "Casa de Subastas"],
  "Animales y Transporte": ["Establo", "Criador de Monturas", "Puerto / Dársena"],
  "Religión y Conocimiento": ["Templo", "Monasterio", "Biblioteca", "Academia de Magia"],
  "Servicios": ["Banco", "Curandero", "Baños Públicos", "Notaría / Registro"],
  "Entretenimiento": ["Teatro", "Arena de Combate", "Casino / Casa de Juegos"],
  "Gobierno": ["Ayuntamiento", "Cuartel de Guardias", "Prisión", "Tribunal"],
  "Mercado Negro": ["Mercado Negro", "Gremio de Ladrones", "Contrabandista"]
}

const vista = ref('lista') 
const ciudades = ref([])
const tiendasDeCiudadActual = ref([])
const ciudadActiva = ref(null)
const tiendaActiva = ref(null)

const busquedaTienda = ref('')
const tiendasFiltradas = computed(() => {
  return tiendasDeCiudadActual.value.filter(t => 
    (t.nombre_personalizado || t.tipo).toLowerCase().includes(busquedaTienda.value.toLowerCase())
  )
})

const formCiudad = ref({ nombre: '', tamano: 'pueblo', descripcion: '' })
const tiendasSeleccionadasParaCrear = ref([])

// --- INVENTARIO, BÚSQUEDA Y SUGERENCIAS FLOTANTES ---
const nuevoItemForm = ref({ nombre: '', cantidad: 1, precio_cobre: 0, bono: '', nivel_objeto: 0 })
const sugPrecioVisible = ref(false) // Controla el globo flotante

// Búsqueda Multivariable: Busca en nombre, precio, cantidad, bono y nivel
const inventarioFiltrado = computed(() => {
  if (!tiendaActiva.value || !tiendaActiva.value.inventario_actual) return []
  const query = nuevoItemForm.value.nombre.toLowerCase().trim()
  if (!query) return tiendaActiva.value.inventario_actual

  return tiendaActiva.value.inventario_actual.filter(i => {
    // Armamos un string gigante con todos los datos del objeto para buscar en cualquier lugar
    const searchStr = `${i.nombre} ${i.cantidad} ${i.precio_cobre} ${i.bono || ''} nvl${i.nivel_objeto || 0} nivel ${i.nivel_objeto || 0}`.toLowerCase()
    return searchStr.includes(query)
  })
})

const sugerenciaPrecio = computed(() => {
  const nvl = nuevoItemForm.value.nivel_objeto
  if (nvl === 0) return "~100 a 500 pc (1 a 5 Plata)"
  if (nvl <= 2) return "~2.000 a 10.000 pc (2 a 10 Oro)"
  if (nvl <= 4) return "~15.000 a 75.000 pc (15 a 75 Oro)"
  if (nvl <= 6) return "~150.000 a 400.000 pc (150 a 400 Oro)"
  if (nvl <= 8) return "~850.000 a 1.500.000 pc (850 a 1.500 Oro)"
  return "Más de 5.000.000 pc (Legendario)"
})

const autoSeleccionarTiendas = () => {
  tiendasSeleccionadasParaCrear.value = []
  const max = tamanos.find(t => t.id === formCiudad.value.tamano).maxTiendas
  let opcionesBase = ['Mercado General', 'Taberna', 'Herrería', 'Templo', 'Posada']
  opcionesBase.forEach(t => { if(tiendasSeleccionadasParaCrear.value.length < max) tiendasSeleccionadasParaCrear.value.push(t) })
  const todas = Object.values(categoriasTiendas).flat()
  while(tiendasSeleccionadasParaCrear.value.length < max) {
    let r = todas[Math.floor(Math.random() * todas.length)]
    if(!tiendasSeleccionadasParaCrear.value.includes(r)) tiendasSeleccionadasParaCrear.value.push(r)
  }
}

const cargarCiudades = async () => {
  const { data } = await supabase.from('ciudades').select('*').order('nombre')
  if (data) ciudades.value = data
}

const crearCiudad = async () => {
  if (!formCiudad.value.nombre) return alert("Ponle un nombre al asentamiento.")
  const { data: nuevaCiu, error } = await supabase.from('ciudades').insert([formCiudad.value]).select().single()
  if (error) return alert(error.message)

  const tAInsertar = tiendasSeleccionadasParaCrear.value.map(tipo => ({
    ciudad_id: nuevaCiu.id,
    campaign_id: route.params.id || null,
    nombre_personalizado: `${tipo} de ${nuevaCiu.nombre}`,
    tipo: tipo,
    inventario_actual: [],
    empleados: []
  }))

  if(tAInsertar.length > 0) await supabase.from('tiendas_sesion').insert(tAInsertar)
  vista.value = 'lista'; cargarCiudades()
}

const guardarCambiosCiudad = async () => {
  await supabase.from('ciudades').update({ nombre: ciudadActiva.value.nombre, descripcion: ciudadActiva.value.descripcion }).eq('id', ciudadActiva.value.id)
  alert("Asentamiento guardado.")
}

const borrarCiudad = async (id) => {
  if(confirm("¿Estás seguro de borrar este asentamiento entero con sus comercios?")) {
    await supabase.from('ciudades').delete().eq('id', id)
    vista.value = 'lista'; cargarCiudades()
  }
}

const abrirCiudad = async (ciudad) => {
  ciudadActiva.value = ciudad
  busquedaTienda.value = ''
  const { data } = await supabase.from('tiendas_sesion').select('*').eq('ciudad_id', ciudad.id).order('tipo')
  if (data) tiendasDeCiudadActual.value = data
  vista.value = 'ciudad-detalle'
}

// --- LÓGICA DE EMPLEADOS POR REFERENCIA (CON EDICIÓN) ---
const mostrandoModalNPC = ref(false)
const npcEditando = ref(null) // El empleado que se pasa al modal
const empleadosCargados = ref([])

const abrirTienda = async (tienda) => {
  tiendaActiva.value = tienda
  if(!tiendaActiva.value.inventario_actual) tiendaActiva.value.inventario_actual = []
  if(!tiendaActiva.value.empleados) tiendaActiva.value.empleados = []

  if(tiendaActiva.value.empleados.length > 0 && typeof tiendaActiva.value.empleados[0] === 'object') {
    tiendaActiva.value.empleados = tiendaActiva.value.empleados.map(e => e.id)
    await supabase.from('tiendas_sesion').update({ empleados: tiendaActiva.value.empleados }).eq('id', tiendaActiva.value.id)
  }

  if (tiendaActiva.value.empleados.length > 0) {
    const { data, error } = await supabase.from('characters').select('*').in('id', tiendaActiva.value.empleados)
    if (data) empleadosCargados.value = data
  } else {
    empleadosCargados.value = []
  }

  vista.value = 'tienda-detalle'
}

const guardarCambiosTienda = async () => {
  const { error } = await supabase.from('tiendas_sesion').update({
    nombre_personalizado: tiendaActiva.value.nombre_personalizado,
    imagen_url: tiendaActiva.value.imagen_url,
    inventario_actual: tiendaActiva.value.inventario_actual
  }).eq('id', tiendaActiva.value.id)
  
  if (error) alert("Error guardando el local: " + error.message)
  else alert("Establecimiento guardado de forma segura.")
}

const borrarTienda = async () => {
  if(confirm("¿Demoler este establecimiento por completo?")) {
    await supabase.from('tiendas_sesion').delete().eq('id', tiendaActiva.value.id)
    abrirCiudad(ciudadActiva.value)
  }
}

// Botón: Inicia la edición de un NPC
const abrirEdicionEmpleado = (emp) => {
  npcEditando.value = emp
  mostrandoModalNPC.value = true
}

// Se dispara al cerrar/guardar el modal
const procesarGuardadoNPC = async (npcGuardado) => {
  mostrandoModalNPC.value = false
  
  if (npcEditando.value) {
    // FUE UNA EDICIÓN: Actualizamos el array local
    const idx = empleadosCargados.value.findIndex(e => e.id === npcGuardado.id)
    if (idx !== -1) empleadosCargados.value[idx] = npcGuardado
  } else {
    // FUE UNA CONTRATACIÓN NUEVA
    tiendaActiva.value.empleados.push(npcGuardado.id)
    empleadosCargados.value.push(npcGuardado)
    await supabase.from('tiendas_sesion').update({ empleados: tiendaActiva.value.empleados }).eq('id', tiendaActiva.value.id)
  }
  
  npcEditando.value = null // Limpiar estado
}

const despedirEmpleado = async (npcId) => {
  if(confirm("¿Seguro que deseas remover a este empleado de la plantilla del local?")) {
    tiendaActiva.value.empleados = tiendaActiva.value.empleados.filter(id => id !== npcId)
    empleadosCargados.value = empleadosCargados.value.filter(e => e.id !== npcId)
    await supabase.from('tiendas_sesion').update({ empleados: tiendaActiva.value.empleados }).eq('id', tiendaActiva.value.id)
  }
}

const generarStockAutomatico = async () => {
  let maxNivelEmpleado = 2
  if (empleadosCargados.value.length > 0) {
    maxNivelEmpleado = Math.max(...empleadosCargados.value.map(e => parseInt(e.nivel) || 0))
  }

  const { data: catalogo, error } = await supabase.from('items_base').select('*')
  if (error || !catalogo) return alert("No se pudo leer el catálogo maestro de objetos.")

  const itemsFiltrados = catalogo.filter(item => item.nivel <= maxNivelEmpleado)
  if (itemsFiltrados.length === 0) return alert(`No hay objetos maestros de nivel <= ${maxNivelEmpleado}.`)

  const nuevoStock = itemsFiltrados.map(item => {
    let cantidadCalculada = 1
    if (item.nivel <= 2) cantidadCalculada = Math.floor(Math.random() * 8) + 6   
    else if (item.nivel <= 5) cantidadCalculada = Math.floor(Math.random() * 4) + 2 
    else cantidadCalculada = Math.floor(Math.random() * 2) + 1                     

    return {
      id: Date.now() + Math.random(),
      nombre: item.nombre,
      cantidad: cantidadCalculada,
      precio_cobre: item.precio_cobre,
      bono: item.bono,
      nivel_objeto: item.nivel || 0
    }
  })

  tiendaActiva.value.inventario_actual = nuevoStock
  await supabase.from('tiendas_sesion').update({ inventario_actual: tiendaActiva.value.inventario_actual }).eq('id', tiendaActiva.value.id)
}

const agregarObjetoALocal = async () => {
  if(!nuevoItemForm.value.nombre) return alert("Escribe el nombre del objeto.")
  
  const nuevoItem = {
    id: Date.now() + Math.random(),
    nombre: nuevoItemForm.value.nombre,
    cantidad: parseInt(nuevoItemForm.value.cantidad) || 1,
    precio_cobre: parseInt(nuevoItemForm.value.precio_cobre) || 0,
    bono: nuevoItemForm.value.bono || null,
    nivel_objeto: parseInt(nuevoItemForm.value.nivel_objeto) || 0
  }

  tiendaActiva.value.inventario_actual.push(nuevoItem)
  await supabase.from('tiendas_sesion').update({ inventario_actual: tiendaActiva.value.inventario_actual }).eq('id', tiendaActiva.value.id)
  
  nuevoItemForm.value = { nombre: '', cantidad: 1, precio_cobre: 0, bono: '', nivel_objeto: 0 }
}

const incrementarItem = async (item) => {
  item.cantidad++
  await supabase.from('tiendas_sesion').update({ inventario_actual: tiendaActiva.value.inventario_actual }).eq('id', tiendaActiva.value.id)
}

const decrementarItem = async (item) => {
  if (item.cantidad > 1) {
    item.cantidad--
    await supabase.from('tiendas_sesion').update({ inventario_actual: tiendaActiva.value.inventario_actual }).eq('id', tiendaActiva.value.id)
  } else {
    tiendaActiva.value.inventario_actual = tiendaActiva.value.inventario_actual.filter(i => i.id !== item.id)
    await supabase.from('tiendas_sesion').update({ inventario_actual: tiendaActiva.value.inventario_actual }).eq('id', tiendaActiva.value.id)
  }
}

const eliminarObjetoDeLocal = async (itemId) => {
  tiendaActiva.value.inventario_actual = tiendaActiva.value.inventario_actual.filter(i => i.id !== itemId)
  await supabase.from('tiendas_sesion').update({ inventario_actual: tiendaActiva.value.inventario_actual }).eq('id', tiendaActiva.value.id)
}

onMounted(() => { cargarCiudades() })
</script>

<template>
  <div class="gestor-wrapper">
    <div class="header-gestor">
      <h2 class="titulo-principal">
        <span v-if="vista === 'lista'">🌍 ATLAS DE LA CAMPAÑA</span>
        <span v-if="vista === 'crear'">🏗️ FUNDAR ASENTAMIENTO</span>
        <span v-if="vista === 'ciudad-detalle'">🏰 URBANISMO: {{ ciudadActiva?.nombre }}</span>
        <span v-if="vista === 'tienda-detalle'">🏪 PANEL DEL ESTABLECIMIENTO</span>
      </h2>
      <div class="acciones-header">
        <button v-if="vista === 'lista'" class="btn-secundario" @click="router.push(`/campanas/${route.params.id}`)">🚪 Salir al Panel</button>
        <button v-if="vista !== 'lista'" class="btn-secundario" @click="vista = 'lista'">🗺️ Volver al Atlas</button>
        <button v-if="vista === 'lista'" class="btn-dorado" @click="vista = 'crear'; autoSeleccionarTiendas()">+ Fundar Asentamiento</button>
      </div>
    </div>

    <div v-if="vista === 'lista'" class="grilla-ciudades">
      <div v-if="ciudades.length === 0" class="mensaje-vacio">El atlas de tierras está vacío. Funda el primer asentamiento.</div>
      <div v-for="c in ciudades" :key="c.id" class="card-ciudad" @click="abrirCiudad(c)">
        <div class="icono-ciudad">🏰</div>
        <div class="info-ciudad">
          <h3>{{ c.nombre }}</h3>
          <span class="tamano-etiqueta">{{ c.tamano.toUpperCase() }}</span>
        </div>
      </div>
    </div>

    <div v-if="vista === 'crear'" class="vista-creacion">
      <div class="form-basico">
        <div class="input-group">
          <label>Nombre del Lugar</label>
          <input type="text" v-model="formCiudad.nombre" class="input-dm" placeholder="Ej: Nexo de Elbion" />
        </div>
        <div class="input-group">
          <label>Magnitud</label>
          <select v-model="formCiudad.tamano" @change="autoSeleccionarTiendas" class="input-dm">
            <option v-for="t in tamanos" :key="t.id" :value="t.id">{{ t.nombre }}</option>
          </select>
        </div>
      </div>
      <div class="selector-tiendas">
        <h3>Locales inyectados automáticamente</h3>
        <div class="grilla-categorias">
          <div v-for="(lugares, cat) in categoriasTiendas" :key="cat" class="categoria-box">
            <h4>{{ cat }}</h4>
            <label v-for="l in lugares" :key="l" class="checkbox-lugar">
              <input type="checkbox" :value="l" v-model="tiendasSeleccionadasParaCrear" />
              <span>{{ l }}</span>
            </label>
          </div>
        </div>
      </div>
      <button class="btn-dorado gigante" @click="crearCiudad">Construir e Inyectar Mapa Urbano</button>
    </div>

    <div v-if="vista === 'ciudad-detalle' && ciudadActiva" class="vista-detalle-ciudad">
      <div class="panel-edicion-ciudad">
        <div class="inputs-inline">
          <input v-model="ciudadActiva.nombre" class="input-dm edit-title" />
          <button @click="guardarCambiosCiudad" class="btn-dorado">💾 Guardar Cambios</button>
          <button @click="borrarCiudad(ciudadActiva.id)" class="btn-rojo">🔥 Demoler Ciudad</button>
        </div>
        <textarea v-model="ciudadActiva.descripcion" placeholder="Notas sobre este lugar..." class="input-dm txt-area mt-1"></textarea>
      </div>
      <div class="barra-busqueda-tiendas">
        <input type="text" v-model="busquedaTienda" placeholder="🔍 Buscar local en las calles..." class="input-dm search-bar" />
      </div>
      <div class="grilla-tiendas">
        <div v-for="t in tiendasFiltradas" :key="t.id" class="card-tienda" @click="abrirTienda(t)">
          <img v-if="t.imagen_url" :src="t.imagen_url" class="img-tienda-real" />
          <div v-else class="icono-tienda">🏠</div>
          <h4>{{ t.nombre_personalizado || t.tipo }}</h4>
          <span class="etiqueta-tipo">{{ t.tipo }}</span>
          <div :class="['indicador-npc', t.empleados?.length > 0 ? 'ok' : 'vacio']">
            👤 Personal: {{ t.empleados?.length || 0 }}
          </div>
        </div>
      </div>
    </div>

    <div v-if="vista === 'tienda-detalle' && tiendaActiva" class="vista-tienda-interna">
      <div class="header-tienda-interna">
        <button class="btn-secundario" @click="abrirCiudad(ciudadActiva)">⬅ Salir a las calles</button>
        <div class="inputs-tienda-crud mt-1">
          <div class="input-group flex-2">
            <label>Nombre Comercial</label>
            <input v-model="tiendaActiva.nombre_personalizado" class="input-dm" />
          </div>
          <div class="input-group flex-2">
            <label>URL Fachada / Imagen</label>
            <input v-model="tiendaActiva.imagen_url" class="input-dm" placeholder="https://..." />
          </div>
          <div class="botones-tienda-fns">
            <button @click="guardarCambiosTienda" class="btn-dorado">💾 Sellar Local</button>
            <button @click="borrarTienda" class="btn-rojo">❌ Demoler</button>
          </div>
        </div>
      </div>

      <div class="paneles-tienda">
        <div class="panel-npc">
          <h3>Plantilla de Personal</h3>
          
          <div class="lista-empleados-scroll" v-if="empleadosCargados.length > 0">
            <div v-for="emp in empleadosCargados" :key="emp.id" class="tarjeta-npc-asignado mb-1">
              <img v-if="emp.imagen_url" :src="emp.imagen_url" class="avatar-empleado-img" />
              <div v-else class="avatar-npc">👤</div>
              <div class="info-npc-asignado w-full">
                <div class="flex-between">
                  <h4>{{ emp.nombre_pj }}</h4>
                  <button @click="abrirEdicionEmpleado(emp)" class="btn-editar-emp">✏️</button>
                </div>
                <p>{{ emp.raza }} {{ emp.clase }} | <strong>Nvl {{ emp.nivel }}</strong></p>
                <button @click="despedirEmpleado(emp.id)" class="btn-despedir">Despedir ✖</button>
              </div>
            </div>
          </div>
          <div v-else class="tarjeta-sin-npc">
            <p class="txt-gris">Local cerrado por falta de personal.</p>
          </div>
          <button @click="npcEditando = null; mostrandoModalNPC = true" class="btn-dorado mt-1 width-100">+ Contratar Empleado</button>
        </div>

        <div class="panel-inventario">
          <div class="header-seccion-inventario">
            <h3>Buscador y Forja de Inventario</h3>
            <button @click="generarStockAutomatico" class="btn-generar-automatico">🎲 Stock Automático</button>
          </div>
          
          <div class="tabla-inventario-container">
            <div class="tabla-grid tabla-header">
              <div class="col-left">Buscar / Nombre</div>
              <div class="col-center">Cant.</div>
              <div class="col-center">Precio (pc)</div>
              <div class="col-left">Bono / Dmg</div>
              <div class="col-center">Nivel</div>
              <div class="col-center">Acción</div>
            </div>

            <div class="tabla-grid tabla-form">
              <input type="text" v-model="nuevoItemForm.nombre" placeholder="Filtra o nombra ítem..." class="input-dm compact search-pulse" />
              <input type="number" v-model="nuevoItemForm.cantidad" class="input-dm compact txt-centro" />
              
              <div class="relative w-full">
                <input 
                  type="number" 
                  v-model="nuevoItemForm.precio_cobre" 
                  @focus="sugPrecioVisible = true" 
                  @blur="sugPrecioVisible = false" 
                  @mouseenter="sugPrecioVisible = true"
                  @mouseleave="sugPrecioVisible = false"
                  class="input-dm compact txt-centro w-full" 
                />
                
                <div class="tooltip-burbuja" v-if="sugPrecioVisible">
                  💡 Sugerencia: {{ sugerenciaPrecio }}
                </div>
              </div>

              <input type="text" v-model="nuevoItemForm.bono" placeholder="Opcional" class="input-dm compact" />
              
              <select 
                v-model.number="nuevoItemForm.nivel_objeto" 
                @mouseenter="sugPrecioVisible = true"
                @mouseleave="sugPrecioVisible = false"
                class="input-dm compact select-nvl">
                <option v-for="n in 11" :key="n-1" :value="n-1">Nvl {{ n-1 }}</option>
              </select>
              
              <button @click="agregarObjetoALocal" class="btn-dorado comp width-100">+ Forjar</button>
            </div>

            <div class="tabla-inventario-scroll mt-1">
              <div v-if="inventarioFiltrado.length === 0" class="mensaje-vacio-busqueda">
                <span v-if="nuevoItemForm.nombre">No hay coincidencias. Haz clic en "+ Forjar" para crearlo y guardarlo.</span>
                <span v-else>El inventario está vacío.</span>
              </div>
              
              <div v-for="item in inventarioFiltrado" :key="item.id" class="tabla-grid tabla-row">
                <div class="col-left nombre-item-lista"><strong>{{ item.nombre }}</strong></div>
                
                <div class="col-center controles-cantidad">
                  <button @click="decrementarItem(item)" class="btn-cant" :class="{'rojo': item.cantidad === 1}">
                    {{ item.cantidad === 1 ? '🗑️' : '-' }}
                  </button>
                  <span class="txt-cantidad">{{ item.cantidad }}</span>
                  <button @click="incrementarItem(item)" class="btn-cant">+</button>
                </div>
                
                <div class="col-center text-oro">💰 {{ item.precio_cobre }}</div>
                <div class="col-left txt-gris">{{ item.bono || '-' }}</div>
                <div class="col-center badge-item-level">Nvl {{ item.nivel_objeto !== undefined ? item.nivel_objeto : 0 }}</div>
                
                <div class="col-center">
                  <button @click="eliminarObjetoDeLocal(item.id)" class="btn-borrar-item-tabla" title="Eliminar del catálogo">✖</button>
                </div>
              </div>
            </div>
          </div>

        </div>
      </div>
    </div>

    <ModalGeneradorNpc 
      v-if="mostrandoModalNPC" 
      :tiendaFijaId="tiendaActiva?.id" 
      :tiendaTipo="tiendaActiva?.tipo" 
      :npcEditando="npcEditando"
      @cerrar="mostrandoModalNPC = false; npcEditando = null" 
      @guardar-npc="procesarGuardadoNPC" 
    />
  </div>
</template>

<style scoped>
/* ESTILOS GLOBALES */
.gestor-wrapper { padding: 20px; color: #e2e8f0; font-family: 'Inter', sans-serif; }
.header-gestor { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #1e293b; padding-bottom: 15px; margin-bottom: 20px; }
.titulo-principal { font-family: 'Cinzel', serif; color: #facc15; font-size: 1.6rem; margin: 0; }
.btn-dorado { background: #b45309; border: 1px solid #f59e0b; color: white; padding: 8px 16px; font-family: 'Cinzel', serif; font-weight: bold; border-radius: 6px; cursor: pointer; transition: 0.2s; }
.btn-dorado:hover { background: #d97706; box-shadow: 0 0 10px rgba(245,158,11,0.4); }
.btn-dorado.gigante { width: 100%; padding: 12px; font-size: 1.1rem; }
.btn-secundario { background: transparent; border: 1px solid #475569; color: #cbd5e1; padding: 8px 16px; border-radius: 6px; cursor: pointer; font-weight: bold; }
.btn-rojo { background: #7f1d1d; border: 1px solid #ef4444; color: white; padding: 8px 16px; border-radius: 6px; cursor: pointer; font-weight: bold; }
.grilla-ciudades { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 20px; }
.card-ciudad { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 10px; padding: 20px; display: flex; align-items: center; gap: 15px; cursor: pointer; transition: 0.2s; }
.card-ciudad:hover { border-color: #3b82f6; transform: translateY(-2px); }
.icono-ciudad { font-size: 2.5rem; }
.info-ciudad h3 { margin: 0 0 5px 0; font-family: 'Cinzel', serif; color: white; }
.tamano-etiqueta { background: rgba(59, 130, 246, 0.15); color: #93c5fd; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: bold; }

/* INPUTS */
.form-basico { display: grid; grid-template-columns: 2fr 1fr; gap: 20px; margin-bottom: 20px; }
.input-group { display: flex; flex-direction: column; gap: 4px; }
.input-group.flex-2 { flex: 2; }
.input-group label { font-size: 0.85rem; color: #94a3b8; font-weight: bold; }
.input-dm { background: #0a0a0c; border: 1px solid #334155; color: white; padding: 10px; border-radius: 6px; outline: none; font-size: 1rem; width: 100%; }
.input-dm:focus { border-color: #facc15; }
.input-dm.edit-title { font-family: 'Cinzel', serif; font-size: 1.5rem; color: #facc15; flex: 1; }
.w-full { width: 100%; box-sizing: border-box; }

/* SELECCIÓN CIUDADES */
.selector-tiendas { background: #0a0a0c; padding: 20px; border-radius: 10px; border: 1px solid #1e293b; margin-bottom: 20px; }
.grilla-categorias { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 15px; }
.categoria-box { background: #111; padding: 12px; border-radius: 6px; border: 1px solid #27272a; }
.categoria-box h4 { color: #facc15; margin: 0 0 10px 0; font-family: 'Cinzel', serif; border-bottom: 1px solid #27272a; padding-bottom: 4px; }
.checkbox-lugar { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; font-size: 0.85rem; cursor: pointer; }
.checkbox-lugar input { accent-color: #facc15; }
.panel-edicion-ciudad { background: #0a0a0c; border: 1px solid #1e293b; padding: 15px; border-radius: 8px; margin-bottom: 15px; }
.inputs-inline { display: flex; gap: 10px; align-items: center; width: 100%; }

/* TIENDAS CALLES */
.barra-busqueda-tiendas { margin-bottom: 15px; }
.input-dm.search-bar { border-color: #3b82f6; background: #050505; font-size: 1.1rem; }
.grilla-tiendas { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 15px; }
.card-tienda { background: #0a0a0c; border: 1px solid #1e293b; padding: 15px; border-radius: 8px; text-align: center; cursor: pointer; transition: 0.2s; overflow: hidden; }
.card-tienda:hover { border-color: #facc15; }
.icono-tienda { font-size: 2rem; margin-bottom: 8px; }
.img-tienda-real { width: 100%; height: 100px; object-fit: cover; border-radius: 6px; margin-bottom: 8px; border: 1px solid #27272a; }
.card-tienda h4 { margin: 0 0 5px 0; font-size: 0.95rem; color: white; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.etiqueta-tipo { font-size: 0.7rem; color: #94a3b8; background: #1e293b; padding: 1px 6px; border-radius: 10px; }
.indicador-npc { margin-top: 10px; font-size: 0.75rem; font-weight: bold; padding: 3px; border-radius: 4px; }
.indicador-npc.ok { color: #4ade80; background: rgba(74,222,128,0.1); }
.indicador-npc.vacio { color: #f59e0b; background: rgba(245,158,11,0.1); }
.inputs-tienda-crud { display: flex; gap: 15px; align-items: flex-end; background: #0a0a0c; padding: 15px; border-radius: 8px; border: 1px solid #1e293b; flex-wrap: wrap; }
.botones-tienda-fns { display: flex; gap: 10px; }

/* PANELES INTERNOS */
.paneles-tienda { display: grid; grid-template-columns: 310px 1fr; gap: 20px; margin-top: 20px; align-items: start; }
.panel-npc, .panel-inventario { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 10px; padding: 15px; }
.panel-npc h3 { margin: 0 0 12px 0; font-family: 'Cinzel', serif; color: #facc15; font-size: 1.1rem; border-bottom: 1px solid #1e293b; padding-bottom: 6px; }

/* EMPLEADOS Y EDICIÓN */
.tarjeta-sin-npc { border: 1px dashed #475569; padding: 15px; border-radius: 6px; text-align: center; font-size: 0.85rem; }
.tarjeta-npc-asignado { display: flex; gap: 10px; background: rgba(59,130,246,0.08); border: 1px solid #1e3a8a; padding: 12px; border-radius: 6px; align-items: center; }
.avatar-npc { font-size: 2rem; }
.avatar-empleado-img { width: 50px; height: 50px; object-fit: cover; border-radius: 50%; border: 1px solid #3b82f6; }
.info-npc-asignado h4 { margin: 0 0 2px 0; font-family: 'Cinzel', serif; color: white; font-size: 0.95rem; }
.info-npc-asignado p { margin: 0 0 6px 0; font-size: 0.8rem; color: #94a3b8; }
.flex-between { display: flex; justify-content: space-between; align-items: center; }
.btn-editar-emp { background: transparent; border: none; font-size: 1rem; cursor: pointer; padding: 0; filter: grayscale(1); transition: 0.2s; }
.btn-editar-emp:hover { filter: grayscale(0); transform: scale(1.1); }
.btn-despedir { background: transparent; border: none; color: #f87171; font-size: 0.75rem; cursor: pointer; padding: 0; font-weight: bold; text-decoration: underline; }
.btn-despedir:hover { color: #ef4444; }

/* TABLA E INVENTARIO */
.header-seccion-inventario { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; border-bottom: 1px solid #1e293b; padding-bottom: 10px; }
.header-seccion-inventario h3 { margin: 0; font-family: 'Cinzel', serif; color: #facc15; font-size: 1.2rem; }
.btn-generar-automatico { background: #1e3a8a; border: 1px solid #3b82f6; color: white; padding: 6px 12px; border-radius: 6px; font-size: 0.8rem; font-weight: bold; cursor: pointer; }
.btn-generar-automatico:hover { background: #2563eb; }

.tabla-inventario-container { width: 100%; }
.tabla-grid { display: grid; grid-template-columns: 2fr 100px 110px 1.5fr 80px 80px; gap: 10px; align-items: center; }
.tabla-header { font-weight: bold; color: #cbd5e1; font-size: 0.8rem; border-bottom: 1px solid #1e293b; padding-bottom: 8px; margin-bottom: 10px; }
.col-left { text-align: left; }
.col-center { text-align: center; }

.tabla-form { background: rgba(30, 58, 138, 0.15); border: 1px solid #1e3a8a; padding: 8px; border-radius: 8px; margin-bottom: 6px; }
.input-dm.compact { padding: 8px; font-size: 0.85rem; border-color: #334155; }
.search-pulse:focus { box-shadow: 0 0 10px rgba(59,130,246,0.3); border-color: #3b82f6; }
.select-nvl { background: #050505; color: #facc15; font-weight: bold; }
.txt-centro { text-align: center; }

/* TOOLTIP FLOTANTE (GLOBO) */
.relative { position: relative; }
.tooltip-burbuja {
  position: absolute;
  bottom: 115%;
  left: 50%;
  transform: translateX(-50%);
  background: #f59e0b;
  color: #000;
  padding: 6px 10px;
  border-radius: 8px;
  font-size: 0.75rem;
  font-weight: bold;
  white-space: nowrap;
  z-index: 50;
  box-shadow: 0 4px 10px rgba(0,0,0,0.5);
  pointer-events: none;
}
.tooltip-burbuja::after {
  content: '';
  position: absolute;
  top: 100%;
  left: 50%;
  margin-left: -5px;
  border-width: 5px;
  border-style: solid;
  border-color: #f59e0b transparent transparent transparent;
}

/* LISTAS DE RESULTADOS */
.tabla-inventario-scroll { max-height: 400px; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; }
.tabla-row { background: #111; border: 1px solid #27272a; padding: 8px; border-radius: 6px; font-size: 0.9rem; transition: 0.2s; }
.tabla-row:hover { border-color: #3f3f46; background: #18181b; }

.nombre-item-lista { color: #f8fafc; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.controles-cantidad { display: flex; justify-content: center; align-items: center; gap: 8px; background: #050505; border-radius: 20px; padding: 2px; border: 1px solid #27272a; }
.btn-cant { background: #1e293b; border: none; color: white; width: 22px; height: 22px; border-radius: 50%; cursor: pointer; font-weight: bold; display: flex; align-items: center; justify-content: center; }
.btn-cant:hover { background: #3b82f6; }
.btn-cant.rojo { background: #7f1d1d; }
.btn-cant.rojo:hover { background: #ef4444; }
.txt-cantidad { font-weight: bold; color: #fca5a5; width: 20px; text-align: center; }

.text-oro { color: #facc15; font-family: monospace; font-weight: bold; font-size: 0.95rem; }
.badge-item-level { background: #1e293b; color: #94a3b8; font-size: 0.75rem; padding: 3px 8px; border-radius: 12px; font-weight: bold; display: inline-block; }
.btn-borrar-item-tabla { background: transparent; border: none; color: #ef4444; cursor: pointer; font-size: 1rem; }
.btn-borrar-item-tabla:hover { color: #f87171; }

.mensaje-vacio-busqueda { text-align: center; color: #f59e0b; font-size: 0.85rem; background: rgba(245,158,11,0.1); padding: 15px; border-radius: 6px; border: 1px dashed #b45309; }
.txt-gris { color: #94a3b8; font-size: 0.85rem; }
.padding-largo { padding: 40px 10px; }
.mt-1 { margin-top: 10px; }
.mb-1 { margin-bottom: 10px; }
.width-100 { width: 100%; }
</style>