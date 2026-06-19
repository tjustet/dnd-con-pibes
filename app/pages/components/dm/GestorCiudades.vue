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

const categoriasTiendasPlan = [
  "Herrería", "Carpintería", "Sastrería", "Joyería", "Alfarería", "Mercado General",
  "Alquimia", "Tienda Arcana", "Biblioteca Arcana", "Adivino / Oráculo",
  "Taberna", "Posada", "Panadería", "Carnicería", "Cervecería / Bodega",
  "Gremio de Aventureros", "Tienda de Suministros", "Cartógrafo", "Casa de Subastas",
  "Establo", "Templo", "Monasterio", "Banco", "Baños Públicos", "Mercado Negro"
]

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

// --- INVENTARIO NORMALIZADO Y FORJA ---
const nuevoItemForm = ref({ nombre: '', cantidad: 1, precio_cobre: 0, bono: '', nivel_objeto: 0 })
const sugPrecioVisible = ref(false)
const inventarioMostrado = ref([]) // Lista cruzada con la BD real para mostrar en UI

const inventarioFiltrado = computed(() => {
  let lista = inventarioMostrado.value
  const qNombre = nuevoItemForm.value.nombre.toLowerCase().trim()
  const qCant = nuevoItemForm.value.cantidad
  const qPrecio = nuevoItemForm.value.precio_cobre
  const qBono = (nuevoItemForm.value.bono || '').toLowerCase().trim()
  const qNvl = nuevoItemForm.value.nivel_objeto

  if (qNombre) lista = lista.filter(i => i.nombre.toLowerCase().includes(qNombre))
  if (qCant !== 1 && qCant !== '' && qCant !== null) lista = lista.filter(i => i.cantidad_en_tienda === qCant)
  if (qPrecio !== 0 && qPrecio !== '' && qPrecio !== null) lista = lista.filter(i => i.precio_cobre === qPrecio)
  if (qBono) lista = lista.filter(i => (i.bono || '').toLowerCase().includes(qBono))
  if (qNvl !== 0) lista = lista.filter(i => i.nivel_objeto === qNvl)

  return lista
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
  while(tiendasSeleccionadasParaCrear.value.length < max) {
    let r = categoriasTiendasPlan[Math.floor(Math.random() * categoriasTiendasPlan.length)]
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
    inventario_actual: [], // Ahora guardará [{ item_id, cantidad, tabla }]
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

// --- CREACIÓN DE NUEVAS TIENDAS EN LA CIUDAD ---
const modalNuevaTienda = ref(false)
const formNuevaTienda = ref({ modo: 'prearmada', tipo: 'Mercado General', nombre: '', imagen_url: '' })

const agregarNuevaTiendaLocal = async () => {
  let nombreFinal = formNuevaTienda.value.nombre
  let tipoFinal = formNuevaTienda.value.tipo

  if (formNuevaTienda.value.modo === 'prearmada') {
    if (!nombreFinal) nombreFinal = `${tipoFinal} de ${ciudadActiva.value.nombre}`
  } else {
    if (!tipoFinal) tipoFinal = 'Comercio Custom'
    if (!nombreFinal) nombreFinal = 'Nuevo Comercio'
  }

  const { data, error } = await supabase.from('tiendas_sesion').insert([{
    ciudad_id: ciudadActiva.value.id,
    campaign_id: route.params.id || null,
    nombre_personalizado: nombreFinal,
    tipo: tipoFinal,
    imagen_url: formNuevaTienda.value.imagen_url || null,
    inventario_actual: [],
    empleados: []
  }]).select().single()

  if (error) return alert("Error creando tienda: " + error.message)
  
  tiendasDeCiudadActual.value.push(data)
  modalNuevaTienda.value = false
  formNuevaTienda.value = { modo: 'prearmada', tipo: 'Mercado General', nombre: '', imagen_url: '' }
}

// --- LÓGICA DE EMPLEADOS ---
const mostrandoModalNPC = ref(false)
const npcEditando = ref(null) 
const empleadosCargados = ref([])
const npcsDeCampaña = ref([]) 
const npcSeleccionadoAsignar = ref('')
const mostrandoSelectorExistente = ref(false)

const cargarTodosLosNpcs = async () => {
  if (!route.params.id) return
  const { data } = await supabase.from('characters').select('id, nombre_pj, clase, nivel').eq('campaign_id', route.params.id)
  if (data) npcsDeCampaña.value = data
}

// --- ABRIR TIENDA Y RESOLVER IDs DE INVENTARIO ---
const abrirTienda = async (tienda) => {
  tiendaActiva.value = tienda
  if(!tiendaActiva.value.inventario_actual) tiendaActiva.value.inventario_actual = []
  if(!tiendaActiva.value.empleados) tiendaActiva.value.empleados = []
  mostrandoSelectorExistente.value = false

  // Cargar Empleados
  if(tiendaActiva.value.empleados.length > 0 && typeof tiendaActiva.value.empleados[0] === 'object') {
    tiendaActiva.value.empleados = tiendaActiva.value.empleados.map(e => e.id || e)
    await supabase.from('tiendas_sesion').update({ empleados: tiendaActiva.value.empleados }).eq('id', tiendaActiva.value.id)
  }
  if (tiendaActiva.value.empleados.length > 0) {
    const { data } = await supabase.from('characters').select('*').in('id', tiendaActiva.value.empleados)
    if (data) empleadosCargados.value = data
  } else { empleadosCargados.value = [] }

  // RESOLVER INVENTARIO (IDs -> Objetos reales)
  inventarioMostrado.value = []
  const itemsGuardados = tiendaActiva.value.inventario_actual
  
  if (itemsGuardados.length > 0) {
    const idsBase = itemsGuardados.filter(i => i.tabla === 'items_base').map(i => i.item_id)
    const idsCustom = itemsGuardados.filter(i => i.tabla === 'items_jugadores').map(i => i.item_id)

    let catBase = [], catCustom = []
    if (idsBase.length > 0) {
      const { data } = await supabase.from('items_base').select('*').in('id', idsBase)
      if(data) catBase = data
    }
    if (idsCustom.length > 0) {
      const { data } = await supabase.from('items_jugadores').select('*').in('id', idsCustom)
      if(data) catCustom = data
    }

    // Fusionamos los datos reales con la cantidad específica de esta tienda
    inventarioMostrado.value = itemsGuardados.map(refGuardada => {
      let itemReal = refGuardada.tabla === 'items_base' 
        ? catBase.find(b => b.id === refGuardada.item_id)
        : catCustom.find(c => c.id === refGuardada.item_id)
      
      if (!itemReal) return null
      return { ...itemReal, cantidad_en_tienda: refGuardada.cantidad, ref_tabla: refGuardada.tabla }
    }).filter(i => i !== null)
  }

  cargarTodosLosNpcs()
  vista.value = 'tienda-detalle'
}

const guardarCambiosTienda = async () => {
  const { error } = await supabase.from('tiendas_sesion').update({
    nombre_personalizado: tiendaActiva.value.nombre_personalizado,
    imagen_url: tiendaActiva.value.imagen_url
  }).eq('id', tiendaActiva.value.id)
  if (error) alert("Error: " + error.message); else alert("Guardado.")
}

const borrarTienda = async () => {
  if(confirm("¿Demoler este establecimiento por completo?")) {
    await supabase.from('tiendas_sesion').delete().eq('id', tiendaActiva.value.id)
    abrirCiudad(ciudadActiva.value)
  }
}

const confirmarAsignarExistente = async () => {
  if (!npcSeleccionadoAsignar.value) return
  if (tiendaActiva.value.empleados.includes(npcSeleccionadoAsignar.value)) return alert("Ese empleado ya trabaja aquí.")
  
  const { data } = await supabase.from('characters').select('*').eq('id', npcSeleccionadoAsignar.value).single()
  if (data) {
    tiendaActiva.value.empleados.push(data.id)
    empleadosCargados.value.push(data)
    await supabase.from('tiendas_sesion').update({ empleados: tiendaActiva.value.empleados }).eq('id', tiendaActiva.value.id)
  }
  mostrandoSelectorExistente.value = false; npcSeleccionadoAsignar.value = ''
}

const abrirEdicionEmpleado = (emp) => { npcEditando.value = emp; mostrandoModalNPC.value = true }

const procesarGuardadoNPC = async (npcGuardado) => {
  mostrandoModalNPC.value = false
  if (npcEditando.value) {
    const idx = empleadosCargados.value.findIndex(e => e.id === npcGuardado.id)
    if (idx !== -1) empleadosCargados.value[idx] = npcGuardado
  } else {
    tiendaActiva.value.empleados.push(npcGuardado.id)
    empleadosCargados.value.push(npcGuardado)
    await supabase.from('tiendas_sesion').update({ empleados: tiendaActiva.value.empleados }).eq('id', tiendaActiva.value.id)
  }
  npcEditando.value = null
}

const despedirEmpleado = async (npcId) => {
  if(confirm("¿Remover a este empleado?")) {
    tiendaActiva.value.empleados = tiendaActiva.value.empleados.filter(id => id !== npcId)
    empleadosCargados.value = empleadosCargados.value.filter(e => e.id !== npcId)
    await supabase.from('tiendas_sesion').update({ empleados: tiendaActiva.value.empleados }).eq('id', tiendaActiva.value.id)
  }
}

// --- ACTUALIZAR INVENTARIO (Sincroniza UI y BD de Referencias) ---
const syncInventarioBD = async () => {
  // Convertimos el array visual a formato de referencias [ {item_id, cantidad, tabla} ]
  const arrayLimpio = inventarioMostrado.value.map(item => ({
    item_id: item.id,
    cantidad: item.cantidad_en_tienda,
    tabla: item.ref_tabla
  }))
  tiendaActiva.value.inventario_actual = arrayLimpio
  await supabase.from('tiendas_sesion').update({ inventario_actual: arrayLimpio }).eq('id', tiendaActiva.value.id)
}

// --- STOCK AUTOMÁTICO RESTRINGIDO (Solo rellena lo que ya está) ---
const generarStockAutomatico = async () => {
  if (inventarioMostrado.value.length === 0) return alert("Esta tienda está vacía. Forja o importa ítems primero. El reabastecimiento solo rellena el stock de los objetos que el local ya comercializa.")
  
  let maxNivelEmpleado = 2
  if (empleadosCargados.value.length > 0) {
    maxNivelEmpleado = Math.max(...empleadosCargados.value.map(e => parseInt(e.nivel) || 0))
  }

  // Iteramos sobre los objetos que la tienda ya tiene y re-calculamos cantidad según nivel empleado
  inventarioMostrado.value.forEach(item => {
    const nivelObj = item.nivel_objeto || item.nivel || 0
    if (nivelObj <= maxNivelEmpleado) {
      if (nivelObj <= 2) item.cantidad_en_tienda = Math.floor(Math.random() * 8) + 6
      else if (nivelObj <= 5) item.cantidad_en_tienda = Math.floor(Math.random() * 4) + 2
      else item.cantidad_en_tienda = Math.floor(Math.random() * 2) + 1
    }
  })

  await syncInventarioBD()
  alert("Vidrieras reabastecidas con éxito basadas en el nivel de los empleados.")
}

// --- FORJAR ITEM NUEVO (Guarda en BD general, luego vincula) ---
const agregarObjetoALocal = async () => {
  if(!nuevoItemForm.value.nombre) return alert("Escribe el nombre del objeto a forjar.")
  
  const objInsertar = {
    campaign_id: route.params.id,
    nombre: nuevoItemForm.value.nombre,
    precio_cobre: parseInt(nuevoItemForm.value.precio_cobre) || 0,
    bono: nuevoItemForm.value.bono || null,
    nivel_objeto: parseInt(nuevoItemForm.value.nivel_objeto) || 0
  }

  // 1. Guardamos el objeto real en la tabla general de la campaña
  const { data: itemCustom, error } = await supabase.from('items_jugadores').insert([objInsertar]).select().single()
  if (error) return alert("Error al forjar: " + error.message)

  // 2. Lo agregamos visualmente a la tienda actual
  inventarioMostrado.value.push({
    ...itemCustom,
    cantidad_en_tienda: parseInt(nuevoItemForm.value.cantidad) || 1,
    ref_tabla: 'items_jugadores'
  })

  // 3. Sincronizamos las referencias
  await syncInventarioBD()
  nuevoItemForm.value = { nombre: '', cantidad: 1, precio_cobre: 0, bono: '', nivel_objeto: 0 }
}

const incrementarItem = async (item) => {
  item.cantidad_en_tienda++
  await syncInventarioBD()
}

const decrementarItem = async (item) => {
  if (item.cantidad_en_tienda > 1) {
    item.cantidad_en_tienda--
  } else {
    inventarioMostrado.value = inventarioMostrado.value.filter(i => i.id !== item.id)
  }
  await syncInventarioBD()
}

const eliminarObjetoDeLocal = async (itemId) => {
  inventarioMostrado.value = inventarioMostrado.value.filter(i => i.id !== itemId)
  await syncInventarioBD()
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
      <div v-if="ciudades.length === 0" class="mensaje-vacio">El atlas está vacío. Funda el primer asentamiento.</div>
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
          <input type="text" v-model="formCiudad.nombre" class="input-dm" />
        </div>
        <div class="input-group">
          <label>Magnitud</label>
          <select v-model="formCiudad.tamano" @change="autoSeleccionarTiendas" class="input-dm">
            <option v-for="t in tamanos" :key="t.id" :value="t.id">{{ t.nombre }}</option>
          </select>
        </div>
      </div>
      <div class="selector-tiendas">
        <h3>Locales recomendados (Borra o agrega)</h3>
        <div class="grilla-categorias">
          <label v-for="l in categoriasTiendasPlan" :key="l" class="checkbox-lugar">
            <input type="checkbox" :value="l" v-model="tiendasSeleccionadasParaCrear" />
            <span>{{ l }}</span>
          </label>
        </div>
      </div>
      <button class="btn-dorado gigante" @click="crearCiudad">Construir Asentamiento</button>
    </div>

    <div v-if="vista === 'ciudad-detalle' && ciudadActiva" class="vista-detalle-ciudad">
      <div class="panel-edicion-ciudad">
        <div class="inputs-inline">
          <input v-model="ciudadActiva.nombre" class="input-dm edit-title" />
          <button @click="guardarCambiosCiudad" class="btn-dorado">💾 Guardar</button>
          <button @click="borrarCiudad(ciudadActiva.id)" class="btn-rojo">🔥 Demoler Ciudad</button>
        </div>
        <textarea v-model="ciudadActiva.descripcion" placeholder="Notas sobre este lugar..." class="input-dm txt-area mt-1"></textarea>
      </div>
      
      <div class="barra-busqueda-tiendas flex-between">
        <input type="text" v-model="busquedaTienda" placeholder="🔍 Buscar local..." class="input-dm search-bar" style="width: 70%" />
        <button @click="modalNuevaTienda = true" class="btn-dorado">+ Nueva Tienda</button>
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

    <div v-if="modalNuevaTienda" class="modal-dm-overlay" @click.self="modalNuevaTienda = false">
      <div class="modal-dm-sheet form-chico">
        <h3 class="t-dorado text-center border-bottom pb-1">Construir Comercio</h3>
        
        <div class="flex-between mt-1 mb-1 btn-grupo-toggle">
          <button @click="formNuevaTienda.modo = 'prearmada'" :class="['btn-toggle', formNuevaTienda.modo === 'prearmada' ? 'activo' : '']">Plantilla Clásica</button>
          <button @click="formNuevaTienda.modo = 'cero'" :class="['btn-toggle', formNuevaTienda.modo === 'cero' ? 'activo' : '']">Desde Cero</button>
        </div>

        <div v-if="formNuevaTienda.modo === 'prearmada'" class="mt-1">
          <label class="txt-gris txt-chico">Selecciona un tipo comercial base</label>
          <select v-model="formNuevaTienda.tipo" class="input-dm w-full mt-1">
            <option v-for="c in categoriasTiendasPlan" :key="c" :value="c">{{ c }}</option>
          </select>
          <input type="text" v-model="formNuevaTienda.nombre" class="input-dm w-full mt-1" placeholder="(Opcional) Nombre Custom" />
        </div>

        <div v-if="formNuevaTienda.modo === 'cero'" class="mt-1">
          <label class="txt-gris txt-chico">Comercio totalmente personalizado</label>
          <input type="text" v-model="formNuevaTienda.tipo" class="input-dm w-full mt-1" placeholder="Rubro (Ej: Casa de Masajes)" />
          <input type="text" v-model="formNuevaTienda.nombre" class="input-dm w-full mt-1" placeholder="Nombre Comercial" />
        </div>

        <input type="text" v-model="formNuevaTienda.imagen_url" class="input-dm w-full mt-1" placeholder="(Opcional) URL Imagen Fachada" />

        <div class="acciones-modal mt-1">
          <button class="btn-cancelar" @click="modalNuevaTienda = false">Cancelar</button>
          <button class="btn-dorado" @click="agregarNuevaTiendaLocal">Construir Local</button>
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
            <label>URL Fachada</label>
            <input v-model="tiendaActiva.imagen_url" class="input-dm" placeholder="https://..." />
          </div>
          <div class="botones-tienda-fns">
            <button @click="guardarCambiosTienda" class="btn-dorado">💾 Guardar Local</button>
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
          <div v-else class="tarjeta-sin-npc"><p class="txt-gris">Local sin personal.</p></div>
          <div class="acciones-contratar mt-1">
            <button v-if="!mostrandoSelectorExistente" @click="npcEditando = null; mostrandoModalNPC = true" class="btn-dorado btn-mitad">+ Nuevo</button>
            <button v-if="!mostrandoSelectorExistente" @click="mostrandoSelectorExistente = true" class="btn-secundario btn-mitad">Existente</button>
            <div v-if="mostrandoSelectorExistente" class="caja-selector-existente">
              <select v-model="npcSeleccionadoAsignar" class="input-dm compact w-full mb-corto">
                <option value="">-- Elegir de la campaña --</option>
                <option v-for="n in npcsDeCampaña" :key="n.id" :value="n.id">{{ n.nombre_pj }} (Nvl {{ n.nivel }})</option>
              </select>
              <div class="flex-between">
                <button @click="mostrandoSelectorExistente = false" class="btn-cancelar mini">Cancelar</button>
                <button @click="confirmarAsignarExistente" class="btn-dorado mini">✔ Asignar</button>
              </div>
            </div>
          </div>
        </div>

        <div class="panel-inventario">
          <div class="header-seccion-inventario">
            <h3>Buscador y Forja de Inventario</h3>
            <button @click="generarStockAutomatico" class="btn-generar-automatico" title="Rellena estanterías según personal">🎲 Reabastecer (Solo catálogo actual)</button>
          </div>
          
          <div class="tabla-inventario-container">
            <div class="tabla-grid tabla-header">
              <div class="col-left">Buscar / Nombre</div>
              <div class="col-center">Cant.</div>
              <div class="col-center">Precio (pc)</div>
              <div class="col-left">Bono / Dmg</div>
              <div class="col-center">Nvl</div>
            </div>

            <div class="caja-forja">
              <div class="tabla-grid">
                <input type="text" v-model="nuevoItemForm.nombre" placeholder="Filtra o nombra ítem..." class="input-dm search-pulse" />
                <input type="number" v-model="nuevoItemForm.cantidad" class="input-dm txt-centro" />
                
                <div class="relative w-full">
                  <input type="number" v-model="nuevoItemForm.precio_cobre" class="input-dm txt-centro w-full" />
                </div>
  
                <input type="text" v-model="nuevoItemForm.bono" placeholder="Opcional" class="input-dm" />
                
                <div class="relative">
                  <select v-model.number="nuevoItemForm.nivel_objeto" @mouseenter="sugPrecioVisible = true" @mouseleave="sugPrecioVisible = false" class="input-dm select-nvl w-full">
                    <option v-for="n in 11" :key="n-1" :value="n-1">Nvl {{ n-1 }}</option>
                  </select>
                  <div class="tooltip-burbuja" v-if="sugPrecioVisible">💡 Sugerido: {{ sugerenciaPrecio }}</div>
                </div>
              </div>
              
              <button @click="agregarObjetoALocal" class="btn-dorado width-100 mt-1" style="padding: 10px; font-size: 1rem;">⚒️ Forjar y Agregar a Tienda</button>
            </div>

            <div class="tabla-inventario-scroll mt-1">
              <div v-if="inventarioFiltrado.length === 0" class="mensaje-vacio-busqueda">
                <span>Vidrieras vacías para esta búsqueda. Usa el botón forjar.</span>
              </div>
              
              <div v-for="item in inventarioFiltrado" :key="item.id" class="tabla-grid-resultados tabla-row">
                <div class="col-left nombre-item-lista">
                  <strong>{{ item.nombre }}</strong>
                  <span class="txt-chico txt-gris d-block ml-1" v-if="item.ref_tabla === 'items_base'">(Catálogo Maestro)</span>
                  <span class="txt-chico text-oro d-block ml-1" v-else>(Forjado a mano)</span>
                </div>
                
                <div class="col-center controles-cantidad">
                  <button @click="decrementarItem(item)" class="btn-cant" :class="{'rojo': item.cantidad_en_tienda === 1}">{{ item.cantidad_en_tienda === 1 ? '🗑️' : '-' }}</button>
                  <span class="txt-cantidad">{{ item.cantidad_en_tienda }}</span>
                  <button @click="incrementarItem(item)" class="btn-cant">+</button>
                </div>
                
                <div class="col-center text-oro">💰 {{ item.precio_cobre }}</div>
                <div class="col-left txt-gris">{{ item.bono || '-' }}</div>
                <div class="col-center badge-item-level">Nvl {{ item.nivel_objeto !== undefined ? item.nivel_objeto : (item.nivel || 0) }}</div>
                <div class="col-center">
                  <button @click="eliminarObjetoDeLocal(item.id)" class="btn-borrar-item-tabla">✖</button>
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
/* LOS ESTILOS SE MANTIENEN IGUAL QUE LA VEZ ANTERIOR PARA NO ROMPER TU DISEÑO, 
   SOLO AGREGUÉ CLASES PARA EL MODAL DE NUEVA TIENDA */
.gestor-wrapper { padding: 20px; color: #e2e8f0; font-family: 'Inter', sans-serif; }
.header-gestor { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #1e293b; padding-bottom: 15px; margin-bottom: 20px; }
.titulo-principal { font-family: 'Cinzel', serif; color: #facc15; font-size: 1.6rem; margin: 0; }
.btn-dorado { background: #b45309; border: 1px solid #f59e0b; color: white; padding: 8px 16px; font-family: 'Cinzel', serif; font-weight: bold; border-radius: 6px; cursor: pointer; transition: 0.2s; }
.btn-dorado:hover { background: #d97706; }
.btn-dorado.gigante { width: 100%; padding: 12px; font-size: 1.1rem; }
.btn-secundario { background: transparent; border: 1px solid #475569; color: #cbd5e1; padding: 8px 16px; border-radius: 6px; cursor: pointer; font-weight: bold; }
.btn-rojo { background: #7f1d1d; border: 1px solid #ef4444; color: white; padding: 8px 16px; border-radius: 6px; cursor: pointer; font-weight: bold; }
.grilla-ciudades { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 20px; }
.card-ciudad { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 10px; padding: 20px; display: flex; align-items: center; gap: 15px; cursor: pointer; transition: 0.2s; }
.card-ciudad:hover { border-color: #3b82f6; transform: translateY(-2px); }
.icono-ciudad { font-size: 2.5rem; }
.info-ciudad h3 { margin: 0 0 5px 0; font-family: 'Cinzel', serif; color: white; }
.tamano-etiqueta { background: rgba(59, 130, 246, 0.15); color: #93c5fd; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: bold; }
.form-basico { display: grid; grid-template-columns: 2fr 1fr; gap: 20px; margin-bottom: 20px; }
.input-group { display: flex; flex-direction: column; gap: 4px; }
.input-group.flex-2 { flex: 2; }
.input-group label { font-size: 0.85rem; color: #94a3b8; font-weight: bold; }
.input-dm { background: #0a0a0c; border: 1px solid #334155; color: white; padding: 10px; border-radius: 6px; outline: none; font-size: 1rem; width: 100%; box-sizing: border-box; }
.input-dm:focus { border-color: #facc15; }
.input-dm.edit-title { font-family: 'Cinzel', serif; font-size: 1.5rem; color: #facc15; flex: 1; }
.w-full { width: 100%; }
.selector-tiendas { background: #0a0a0c; padding: 20px; border-radius: 10px; border: 1px solid #1e293b; margin-bottom: 20px; }
.grilla-categorias { display: flex; flex-wrap: wrap; gap: 10px; }
.checkbox-lugar { display: flex; align-items: center; gap: 8px; background: #111; padding: 8px 12px; border-radius: 6px; border: 1px solid #27272a; cursor: pointer; font-size: 0.85rem;}
.checkbox-lugar input { accent-color: #facc15; }
.panel-edicion-ciudad { background: #0a0a0c; border: 1px solid #1e293b; padding: 15px; border-radius: 8px; margin-bottom: 15px; }
.inputs-inline { display: flex; gap: 10px; align-items: center; width: 100%; }
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
.paneles-tienda { display: grid; grid-template-columns: 310px 1fr; gap: 20px; margin-top: 20px; align-items: start; }
.panel-npc, .panel-inventario { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 10px; padding: 15px; }
.panel-npc h3 { margin: 0 0 12px 0; font-family: 'Cinzel', serif; color: #facc15; font-size: 1.1rem; border-bottom: 1px solid #1e293b; padding-bottom: 6px; }
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
.acciones-contratar { display: flex; flex-wrap: wrap; gap: 10px; justify-content: space-between; }
.btn-mitad { flex: 1; text-align: center; padding: 8px; font-size: 0.85rem; }
.caja-selector-existente { width: 100%; background: #111; padding: 10px; border-radius: 6px; border: 1px solid #3b82f6; }
.btn-cancelar.mini, .btn-dorado.mini { padding: 4px 8px; font-size: 0.75rem; }
.header-seccion-inventario { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; border-bottom: 1px solid #1e293b; padding-bottom: 10px; }
.header-seccion-inventario h3 { margin: 0; font-family: 'Cinzel', serif; color: #facc15; font-size: 1.2rem; }
.btn-generar-automatico { background: #1e3a8a; border: 1px solid #3b82f6; color: white; padding: 6px 12px; border-radius: 6px; font-size: 0.8rem; font-weight: bold; cursor: pointer; }
.tabla-inventario-container { width: 100%; }
.tabla-grid { display: grid; grid-template-columns: 2fr 100px 110px 1.5fr 100px; gap: 10px; align-items: center; }
.tabla-grid-resultados { display: grid; grid-template-columns: 2fr 100px 110px 1.5fr 100px 50px; gap: 10px; align-items: center; }
.tabla-header { font-weight: bold; color: #cbd5e1; font-size: 0.8rem; border-bottom: 1px solid #1e293b; padding-bottom: 8px; margin-bottom: 10px; padding-right: 60px; }
.col-left { text-align: left; }
.col-center { text-align: center; }
.caja-forja { background: rgba(30, 58, 138, 0.15); border: 1px solid #1e3a8a; padding: 12px; border-radius: 8px; margin-bottom: 15px; }
.input-dm.compact { font-size: 0.9rem; }
.search-pulse:focus { box-shadow: 0 0 10px rgba(59,130,246,0.3); border-color: #3b82f6; }
.select-nvl { background: #050505; color: #facc15; font-weight: bold; }
.txt-centro { text-align: center; }
.relative { position: relative; }
.tooltip-burbuja { position: absolute; bottom: 120%; left: 50%; transform: translateX(-50%); background: #f59e0b; color: #000; padding: 8px 12px; border-radius: 8px; font-size: 0.8rem; font-weight: bold; white-space: nowrap; z-index: 50; box-shadow: 0 4px 10px rgba(0,0,0,0.5); pointer-events: none; }
.tooltip-burbuja::after { content: ''; position: absolute; top: 100%; left: 50%; margin-left: -6px; border-width: 6px; border-style: solid; border-color: #f59e0b transparent transparent transparent; }
.tabla-inventario-scroll { max-height: 400px; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; }
.tabla-row { background: #111; border: 1px solid #27272a; padding: 8px; border-radius: 6px; font-size: 0.9rem; transition: 0.2s; }
.tabla-row:hover { border-color: #3f3f46; background: #18181b; }
.nombre-item-lista { color: #f8fafc; overflow: hidden; text-overflow: ellipsis; }
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
.txt-chico { font-size: 0.75rem; }
.d-block { display: block; }
.mt-1 { margin-top: 10px; }
.mb-1 { margin-bottom: 10px; }
.pb-1 { padding-bottom: 10px; }
.mb-corto { margin-bottom: 5px; }
.width-100 { width: 100%; }

/* MODAL DE TIENDA NUEVA */
.form-chico { width: 400px; max-width: 90vw; background: #0a0a0c; border: 2px solid #334155; border-radius: 12px; padding: 1.5rem; }
.border-bottom { border-bottom: 1px solid #1e293b; }
.btn-grupo-toggle { display: flex; background: #111; border-radius: 6px; border: 1px solid #27272a; overflow: hidden; }
.btn-toggle { flex: 1; padding: 8px; background: transparent; border: none; color: #94a3b8; cursor: pointer; font-size: 0.85rem; font-weight: bold; }
.btn-toggle.activo { background: #3b82f6; color: white; }
.btn-cancelar { background: transparent; border: 1px solid #475569; color: white; padding: 8px 16px; border-radius: 6px; cursor: pointer; }
.text-center { text-align: center; }
</style>