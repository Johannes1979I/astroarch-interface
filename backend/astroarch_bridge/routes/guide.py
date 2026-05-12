"""Route /api/guide: PHD2."""
from __future__ import annotations

from fastapi import APIRouter, Body, Depends, HTTPException

from ..auth import require_token
from ..deps import Bridge, get_bridge
from ..phd2.client import Phd2RpcError

router = APIRouter(prefix="/api/guide", tags=["guide"], dependencies=[Depends(require_token)])


@router.get("/status")
async def status(bridge: Bridge = Depends(get_bridge)) -> dict:
    return {
        "connection": bridge.phd2.state,
        "live": dict(bridge.phd2.live),
    }


@router.post("/start")
async def start(
    payload: dict = Body(default={}),
    bridge: Bridge = Depends(get_bridge),
) -> dict:
    try:
        result = await bridge.phd2.start_guiding(
            settle_pixels=float(payload.get("settle_pixels", 1.5)),
            settle_time=float(payload.get("settle_time", 10.0)),
            settle_timeout=float(payload.get("settle_timeout", 60.0)),
        )
    except (ConnectionError, Phd2RpcError) as e:
        raise HTTPException(status_code=503, detail=str(e))
    return {"ok": True, "result": result}


@router.post("/stop")
async def stop(bridge: Bridge = Depends(get_bridge)) -> dict:
    try:
        await bridge.phd2.stop_capture()
    except (ConnectionError, Phd2RpcError) as e:
        raise HTTPException(status_code=503, detail=str(e))
    return {"ok": True}


@router.post("/dither")
async def dither(
    payload: dict = Body(default={}),
    bridge: Bridge = Depends(get_bridge),
) -> dict:
    try:
        result = await bridge.phd2.dither(
            amount=float(payload.get("amount", 3.0)),
            ra_only=bool(payload.get("ra_only", False)),
            settle_pixels=float(payload.get("settle_pixels", 1.5)),
            settle_time=float(payload.get("settle_time", 10.0)),
            settle_timeout=float(payload.get("settle_timeout", 60.0)),
        )
    except (ConnectionError, Phd2RpcError) as e:
        raise HTTPException(status_code=503, detail=str(e))
    return {"ok": True, "result": result}


@router.post("/loop")
async def loop_(bridge: Bridge = Depends(get_bridge)) -> dict:
    try:
        await bridge.phd2.loop()
    except (ConnectionError, Phd2RpcError) as e:
        raise HTTPException(status_code=503, detail=str(e))
    return {"ok": True}


@router.post("/clear_calibration")
async def clear_calibration(
    payload: dict = Body(default={}),
    bridge: Bridge = Depends(get_bridge),
) -> dict:
    which = payload.get("which", "Both")
    try:
        await bridge.phd2.clear_calibration(which)
    except (ConnectionError, Phd2RpcError) as e:
        raise HTTPException(status_code=503, detail=str(e))
    return {"ok": True}


@router.post("/pause")
async def pause(
    payload: dict = Body(default={}),
    bridge: Bridge = Depends(get_bridge),
) -> dict:
    try:
        await bridge.phd2.set_paused(bool(payload.get("paused", True)),
                                    full=bool(payload.get("full", False)))
    except (ConnectionError, Phd2RpcError) as e:
        raise HTTPException(status_code=503, detail=str(e))
    return {"ok": True}


@router.post("/find_star")
async def find_star(bridge: Bridge = Depends(get_bridge)) -> dict:
    try:
        r = await bridge.phd2.call("find_star")
    except (ConnectionError, Phd2RpcError) as e:
        raise HTTPException(status_code=503, detail=str(e))
    return {"ok": True, "result": r}


@router.post("/calibrate")
async def calibrate(bridge: Bridge = Depends(get_bridge)) -> dict:
    """Avvia calibration completa: clear cal -> guide (forza recalibrate)."""
    try:
        await bridge.phd2.call("clear_calibration", "Both")
        await bridge.phd2.call("guide", {
            "settle": {"pixels": 1.5, "time": 10.0, "timeout": 60.0},
            "recalibrate": True,
        })
    except (ConnectionError, Phd2RpcError) as e:
        raise HTTPException(status_code=503, detail=str(e))
    return {"ok": True}


@router.get("/profile")
async def profile(bridge: Bridge = Depends(get_bridge)) -> dict:
    """Restituisce info su profilo guide attivo (camera, mount, scope)."""
    try:
        eq = await bridge.phd2.call("get_current_equipment", timeout=5.0)
    except Exception:
        eq = None
    info: dict = {"equipment": eq or {}}
    try:
        info["pixel_scale"] = await bridge.phd2.call("get_pixel_scale", timeout=3.0)
    except Exception:
        pass
    try:
        info["calibrated"] = await bridge.phd2.call("get_calibrated", timeout=3.0)
    except Exception:
        pass
    try:
        info["app_state"] = await bridge.phd2.call("get_app_state", timeout=3.0)
    except Exception:
        pass
    return info


@router.get("/star_image")
async def star_image(
    fmt: str = "json", size: int = 0,
    bridge: Bridge = Depends(get_bridge),
):
    """Ritorna l'immagine del riquadro intorno alla stella di guida di PHD2.

    PHD2 espone `get_star_image` via JSON-RPC che ritorna:
      {
        "frame": int,                  # numero frame
        "width": int, "height": int,   # dimensioni del crop in pixel
        "star_pos": [x, y],            # posizione stella nel crop
        "pixels": "<base64-rawdata>"   # array di uint16 little-endian
      }
    Lo riconvertiamo in PNG 8-bit stretchato (auto-stretch in stile PI)
    così la app può mostrarlo direttamente con <Image.memory>.

    Query:
      fmt:  "json" (default, ritorna anche PNG in base64) o "png" (binary)
      size: opzionale, suggerimento dimensione (ignorato da PHD2 di solito)
    """
    import base64
    import io
    import struct
    import numpy as np
    from fastapi.responses import Response
    from ..images.processor import _percentile_stretch

    params: list = []
    if size > 0:
        params = [size]
    try:
        res = await bridge.phd2.call("get_star_image", params, timeout=5.0)
    except Phd2RpcError as e:
        # PHD2 ritorna errore se non c'è stella selezionata o se è in modalità
        # incompatibile (es. looping ma senza star)
        raise HTTPException(status_code=409,
                            detail=f"PHD2: {e}")
    except (ConnectionError, Exception) as e:
        raise HTTPException(status_code=503, detail=f"PHD2 not reachable: {e}")

    if not isinstance(res, dict) or "pixels" not in res:
        raise HTTPException(status_code=502,
                            detail=f"PHD2 get_star_image bad payload: {res}")

    w = int(res.get("width", 0))
    h = int(res.get("height", 0))
    if w <= 0 or h <= 0:
        raise HTTPException(status_code=502, detail="PHD2: invalid image size")

    # pixels è base64 di un array di uint16 (PHD2 convention)
    try:
        raw = base64.b64decode(res["pixels"])
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"PHD2 b64 decode: {e}")

    if len(raw) != w * h * 2:
        raise HTTPException(status_code=502,
                            detail=f"PHD2: pixel buffer len {len(raw)} != {w*h*2}")

    arr = np.frombuffer(raw, dtype="<u2").reshape((h, w)).astype(np.float64)

    # Stretch con lo stesso algoritmo che usiamo per i frame Ekos.
    stretched = _percentile_stretch(arr)

    # Crea PNG via PIL
    try:
        from PIL import Image
        img = Image.fromarray(stretched, mode="L").convert("RGB")
        buf = io.BytesIO()
        img.save(buf, format="PNG", optimize=False)
        png_bytes = buf.getvalue()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PNG encode: {e}")

    star_pos = res.get("star_pos") or [w / 2.0, h / 2.0]
    payload = {
        "frame": res.get("frame"),
        "width": w,
        "height": h,
        "star_x": float(star_pos[0]) if len(star_pos) > 0 else None,
        "star_y": float(star_pos[1]) if len(star_pos) > 1 else None,
    }

    if fmt.lower() == "png":
        return Response(content=png_bytes, media_type="image/png",
                        headers={"Cache-Control": "no-store",
                                 "X-Star-X": str(payload["star_x"] or ""),
                                 "X-Star-Y": str(payload["star_y"] or ""),
                                 "X-Width": str(w),
                                 "X-Height": str(h),
                                 "X-Frame": str(payload["frame"] or "")})
    payload["png_base64"] = base64.b64encode(png_bytes).decode("ascii")
    return payload
