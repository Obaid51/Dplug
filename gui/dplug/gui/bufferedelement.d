/**
* Copyright: Copyright Auburn Sounds 2015-2016.
* License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
* Authors:   Guillaume Piolat
*/
module dplug.gui.bufferedelement;

import dplug.core.nogc;
public import dplug.gui.element;

// Important values for opacity.
enum L8 opacityFullyOpaque = L8(255);
enum L8 opacityFullyTransparent = L8(0);

///Extending the UIElement with an owned drawing buffer.
/// This is intended to have easier dirtyrect-compliant widgets.
/// Also caches expensive drawing, but it's not free at all.
///
/// No less than three additional opacity channels must be filled to be able to blend the widgets explicitely.
/// The semantic of the opacity channels are:
///   opacity left at 0 => pixel untouched
///   opacity > 0       => pixel is touched, blending will occur
class UIBufferedElement : UIElement
{
public:
nothrow:
@nogc:

    this(UIContext context)
    {
        super(context);
        _diffuseBuf = mallocEmplace!(OwnedImage!RGBA)();
        _depthBuf = mallocEmplace!(OwnedImage!L16)();
        _materialBuf = mallocEmplace!(OwnedImage!RGBA)();

        _diffuseOpacityBuf = mallocEmplace!(OwnedImage!L8)();
        _depthOpacityBuf = mallocEmplace!(OwnedImage!L8)();
        _materialOpacityBuf = mallocEmplace!(OwnedImage!L8)();
    }

    ~this()
    {
        _diffuseBuf.destroyFree();
        _depthBuf.destroyFree();
        _materialBuf.destroyFree();

        _diffuseOpacityBuf.destroyFree();
        _depthOpacityBuf.destroyFree();
        _materialOpacityBuf.destroyFree();
    }
    
    override void setDirty(box2i rect) nothrow @nogc 
    {
        super.setDirty(rect);
        _mustBeRedrawn = true; // the content of the cached buffer will change, need to be redrawn
    }

    override void setDirtyWhole() nothrow @nogc 
    {
        super.setDirtyWhole();
        _mustBeRedrawn = true; // the content of the cached buffer will change, need to be redrawn
    }

    override void onDraw(ImageRef!RGBA diffuseMap, ImageRef!L16 depthMap, ImageRef!RGBA materialMap, box2i[] dirtyRects) nothrow @nogc
    {
        // Did the element's size changed?
        int currentWidth = _diffuseBuf.w;
        int currentHeight = _diffuseBuf.h;
        int newWidth = _position.width;
        int newHeight = _position.height;
        bool sizeChanged = (currentWidth != newWidth) || (currentHeight != newHeight);
        if (sizeChanged)
        {
            // If the widget size changed, we must redraw it even if it was not dirtied
            _mustBeRedrawn = true;

            // Change size of buffers
            _diffuseBuf.size(newWidth, newHeight);
            _depthBuf.size(newWidth, newHeight);
            _materialBuf.size(newWidth, newHeight);

            _diffuseOpacityBuf.size(newWidth, newHeight);
            _depthOpacityBuf.size(newWidth, newHeight);
            _materialOpacityBuf.size(newWidth, newHeight);
        }

        if (_mustBeRedrawn)
        {
            // opacity buffer originally filled with zeroes
            _diffuseOpacityBuf.fill(opacityFullyTransparent);
            _depthOpacityBuf.fill(opacityFullyTransparent);
            _materialOpacityBuf.fill(opacityFullyTransparent);

            _diffuseBuf.fill(RGBA(128, 128, 128, 0));
            _depthBuf.fill(L16(defaultDepth));
            _materialBuf.fill(RGBA(defaultRoughness, defaultMetalnessMetal, defaultSpecular, defaultPhysical));

            onDrawBuffered(_diffuseBuf.toRef(), _depthBuf.toRef(), _materialBuf.toRef(), 
                           _diffuseOpacityBuf.toRef(),
                           _depthOpacityBuf.toRef(),
                           _materialOpacityBuf.toRef());

            // For debug purpose            
            //_diffuseOpacityBuf.fill(opacityFullyOpaque);
            //_depthOpacityBuf.fill(opacityFullyOpaque);
            //_materialOpacityBuf.fill(opacityFullyOpaque);

            _mustBeRedrawn = false;
        }

        // Blend cached render to given targets
        foreach(dirtyRect; dirtyRects)
        {
            auto sourceDiffuse = _diffuseBuf.toRef().cropImageRef(dirtyRect);
            auto sourceDepth = _depthBuf.toRef().cropImageRef(dirtyRect);
            auto sourceMaterial = _materialBuf.toRef().cropImageRef(dirtyRect);
            auto destDiffuse = diffuseMap.cropImageRef(dirtyRect);
            auto destDepth = depthMap.cropImageRef(dirtyRect);
            auto destMaterial = materialMap.cropImageRef(dirtyRect);

            sourceDiffuse.blendWithAlpha(destDiffuse, _diffuseOpacityBuf.toRef().cropImageRef(dirtyRect));
            sourceDepth.blendWithAlpha(destDepth, _depthOpacityBuf.toRef().cropImageRef(dirtyRect));
            sourceMaterial.blendWithAlpha(destMaterial, _materialOpacityBuf.toRef().cropImageRef(dirtyRect));
        }
    }

    /// Redraws the whole widget without consideration for drawing only in dirty rects.
    /// That is a lot of maps to fill. On the plus side, this happen quite infrequently.
    abstract void onDrawBuffered(ImageRef!RGBA diffuse, 
                                 ImageRef!L16 depth, 
                                 ImageRef!RGBA material, 
                                 ImageRef!L8 diffuseOpacity,
                                 ImageRef!L8 depthOpacity,
                                 ImageRef!L8 materialOpacity) nothrow @nogc;

private:
    OwnedImage!RGBA _diffuseBuf;
    OwnedImage!L16 _depthBuf;
    OwnedImage!RGBA _materialBuf;
    OwnedImage!L8 _diffuseOpacityBuf;
    OwnedImage!L8 _depthOpacityBuf;
    OwnedImage!L8 _materialOpacityBuf;
    bool _mustBeRedrawn;
}

