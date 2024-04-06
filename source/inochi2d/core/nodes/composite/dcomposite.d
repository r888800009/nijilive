/*
    Inochi2D Composite Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.composite.dcomposite;
import inochi2d.core.nodes.common;
import inochi2d.core.nodes;
import inochi2d.fmt;
import inochi2d.core;
import inochi2d.math;
import inochi2d;
import bindbc.opengl;
import std.exception;
import std.algorithm;
import std.algorithm.sorting;
import std.stdio;

package(inochi2d) {
    void inInitDComposite() {
        inRegisterNodeType!DynamicComposite;
    }
}

/**
    Composite Node
*/
@TypeId("DynamicComposite")
class DynamicComposite : Part {
private:
    bool initialized = false;
    bool autoResizedMesh = true;

    this() { }

    void drawContents() {
        // Optimization: Nothing to be drawn, skip context switching
//        writefln("drawComponents:%s, %d", name, subParts.length);
//        if (subParts.length == 0) return;

        if (beginComposite()) {
            mat4* origTransform = oneTimeTransform;
            mat4 tmpTransform = transform.matrix.inverse;
//            writefln("transform=%s", transform);
            Camera camera = inGetCamera();
//            writefln("%10.3f: draw sub-parts: %s(%dx%d):+%s,x%s", currentTime(), name, textures[0].width, textures[0].height, camera.position, camera.scale);
            setOneTimeTransform(&tmpTransform);
            foreach(Part child; subParts) {
//                writefln("draw %s::%s", name, child.name);
                child.drawOne();
            }
            setOneTimeTransform(origTransform);
            endComposite();
            textures[0].genMipmap();
        }
        textureInvalidated = false;
    }


    void selfSort() {
        import std.math : cmp;
        sort!((a, b) => cmp(
            a.zSort, 
            b.zSort) > 0)(subParts);
    }

    void scanPartsRecurse(ref Node node) {

        // Don't need to scan null nodes
        if (node is null) return;
        //writefln("scanParts: %s-->%s", name, node.name);

        // Do the main check
        DynamicComposite dcomposite = cast(DynamicComposite)node;
        Part part = cast(Part)node;
        if (part !is null && node != this) {
            subParts ~= part;
            part.ignorePuppet = ignorePuppet;
            if (dcomposite is null) {
                foreach(child; part.children) {
                    scanPartsRecurse(child);
                }
            } else {
                //writefln("Recursive scanParts call to %s", name);
                dcomposite.scanParts();
            }
            
        } else if (dcomposite is null || node == this) {

            // Non-part nodes just need to be recursed through,
            // they don't draw anything.
            foreach(child; node.children) {
                scanPartsRecurse(child);
            }
        } else if (dcomposite !is null && node != this) {
            //writefln("Recursive scanParts call to %s", name);
            dcomposite.scanParts();
        }
    }

    void setIgnorePuppetRecurse(Part part, bool ignorePuppet) {
        part.ignorePuppet = ignorePuppet;
        foreach (child; part.children) {
            if (Part pChild = cast(Part)child)
                setIgnorePuppetRecurse(pChild, ignorePuppet);
        }
    }

    void setIgnorePuppet(bool ignorePuppet) {
        foreach (child; children) {
            if (Part pChild = cast(Part)child)
                setIgnorePuppetRecurse(pChild, ignorePuppet);
        }

    }

protected:
    GLuint cfBuffer;
    GLint origBuffer;
//    Texture stencil;
    GLint[4] origViewport;
    bool textureInvalidated = false;
    bool initTarget() {
        if (textures[0] !is null) {
            textures[0].dispose();
            textures[0] = null;
        }

        updateBounds();
        

        vec4 bounds = this.bounds;
        if (autoResizedMesh)
            bounds = getChildrenBounds();
        uint width = cast(uint)(bounds.z-bounds.x);
        uint height = cast(uint)(bounds.w-bounds.y);
        if (width == 0 || height == 0) return false;
        textureOffset = vec2((bounds.x + bounds.z) / 2 - transform.translation.x, (bounds.y + bounds.w) / 2 - transform.translation.y);
//        writefln("bounds=%s, translation=%s, textureOffset=%s", bounds, transform.translation, textureOffset);
        setIgnorePuppet(true);

        glGenFramebuffers(1, &cfBuffer);
        ubyte[] buffer;
        buffer.length = cast(uint)(width) * cast(uint)(height) * 4;
        textures = [new Texture(ShallowTexture(buffer, width, height)), null, null];
//        stencil = new Texture(ShallowTexture(buffer, width, height));

        glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &origBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, cfBuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textures[0].getTextureId(), 0);
//        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, stencil.getTextureId(), 0);

        // go back to default fb
        glBindFramebuffer(GL_FRAMEBUFFER, origBuffer);
//        scanParts!true();

        initialized = true;
        textureInvalidated = true;
        return true;
    }
    bool beginComposite() {
        if (!initialized) {
            if (!initTarget()) {
//                writefln("initialize failed:%s", name);
                return false;
            } else {
//                writefln("initialized:%s", name);
            }
        }
        if (textureInvalidated) {
            glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &origBuffer);
            glGetIntegerv(GL_VIEWPORT, cast(GLint*)origViewport);
//            writefln("%s: framebuffer to %x, texture=%x(%dx%d)", name, cfBuffer, textures[0].getTextureId(), textures[0].width, textures[0].height);
            glBindFramebuffer(GL_FRAMEBUFFER, cfBuffer);
            inPushViewport(textures[0].width, textures[0].height);
            Camera camera = inGetCamera();
            camera.scale = vec2(1, -1);
            camera.position = -textureOffset;
            glViewport(0, 0, textures[0].width, textures[0].height);
            glClearColor(0, 0, 0, 0);
            glClear(GL_COLOR_BUFFER_BIT);

            // Everything else is the actual texture used by the meshes at id 0
            glActiveTexture(GL_TEXTURE0);
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        }
        return textureInvalidated;
    }
    void endComposite() {
//        import std.stdio;
//        writefln("framebuffer to %x", origBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, origBuffer);
        inPopViewport();
        glViewport(origViewport[0], origViewport[1], origViewport[2], origViewport[3]);
        glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);
        glFlush();
    }

    Part[] subParts;
    
    override
    string typeId() { return "DynamicComposite"; }

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelfImpl(ref InochiSerializer serializer, bool recursive = true) {
        Texture[3] tmpTextures = textures;
        textures = [null, null, null];
        super.serializeSelfImpl(serializer, recursive);
        serializer.putKey("auto_resized");
        serializer.serializeValue(autoResizedMesh);
        textures = tmpTextures;
    }

    override
    SerdeException deserializeFromFghj(Fghj data) {
        auto result = super.deserializeFromFghj(data);
        textures = [null, null, null];
        if (!data["auto_resized"].isEmpty) 
            data["auto_resized"].deserializeValue(autoResizedMesh);
        else if (this.data.indices.length != 0) {
            autoResizedMesh = false;
        } else autoResizedMesh = true;
        return result;
    }

    vec4 getChildrenBounds() {
        if (subParts.length > 0) {
            float minX = subParts.map!(p=> p.bounds.x).minElement();
            float minY = subParts.map!(p=> p.bounds.y).minElement();
            float maxX = subParts.map!(p=> p.bounds.z).maxElement();
            float maxY = subParts.map!(p=> p.bounds.w).maxElement();
            return vec4(minX, minY, maxX, maxY);
        } else {
            return transform.translation.xyxy;
        }
    }

    bool createSimpleMesh() {
        auto origBounds = this.bounds;
        auto bounds = getChildrenBounds();
        vec2 origSize = origBounds.zw - origBounds.xy;
        vec2 size = bounds.zw - bounds.xy;
        if (cast(int)origSize.x == cast(int)size.x && cast(int)origSize.y == cast(int)size.y) {
//            writefln("same boundary, skip %s", size);
            textureOffset = vec2((bounds.x + bounds.z) / 2 - transform.translation.x, (bounds.y + bounds.w) / 2 - transform.translation.y);
            return false;
        } else {
//            writefln("update bounds %s->%s", origSize, size);
            data.vertices = [
                vec2(bounds.x, bounds.y) - transform.translation.xy,
                vec2(bounds.x, bounds.w) - transform.translation.xy,
                vec2(bounds.z, bounds.y) - transform.translation.xy,
                vec2(bounds.z, bounds.w) - transform.translation.xy
            ];
            data.uvs = [
                vec2(0, 0),
                vec2(0, 1),
                vec2(1, 0),
                vec2(1, 1),
            ];
            data.indices = [
                0, 1, 2,
                2, 1, 3
            ];
            this.updateIndices();
            this.updateVertices();
            updateBounds();
            size = bounds.zw - bounds.xy;
//            writefln("mew bounds %s", size);
        }
        textureOffset = vec2((bounds.x + bounds.z) / 2 - transform.translation.x, (bounds.y + bounds.w) / 2 - transform.translation.y);
        return true;
    }

public:
    vec2 textureOffset;

    /**
        Constructs a new mask
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        Constructs a new composite
    */
    this(MeshData data, uint uuid, Node parent = null) {
        if (data.indices.length != 0) autoResizedMesh = false;
        super(data, uuid, parent);
    }

    override
    void drawOne() {
        if (!enabled) return;
        
        this.selfSort();
        this.drawContents();

        // No masks, draw normally
        drawSelf();
    }

    override
    void draw() {
        if (!enabled) return;
        this.drawOne();
    }


    /**
        Scans for parts to render
    */
    void scanParts() {
        subParts.length = 0;
        if (children.length > 0) {
            scanPartsRecurse(children[0].parent);
        }
//        import std.algorithm;
//        writefln("%s: %s", name, subParts.map!(p => p.name));
    }

    override
    void setupChild(Node node) {
        if (Part part = cast(Part)node)
            setIgnorePuppetRecurse(part, true);
    }

    override
    void releaseChild(Node node) {
        if (Part part = cast(Part)node)
            setIgnorePuppetRecurse(part, false);
    }

    override
    void normalizeUV(MeshData* data) {
        import std.algorithm: map;
        import std.algorithm: minElement, maxElement;
        float minX = data.uvs.map!(a => a.x).minElement;
        float maxX = data.uvs.map!(a => a.x).maxElement;
        float minY = data.uvs.map!(a => a.y).minElement;
        float maxY = data.uvs.map!(a => a.y).maxElement;
        float width = maxX - minX;
        float height = maxY - minY;
        float centerX = (minX + maxX) / 2 / width;
        float centerY = (minY + maxY) / 2 / height;
        foreach(i; 0..data.uvs.length) {
            // Texture 0 is always albedo texture
            auto tex = textures[0];
            data.uvs[i].x /= width;
            data.uvs[i].y /= height;
            data.uvs[i] += vec2(0.5 - centerX, 0.5 - centerY);
        }
    }

    override
    void notifyChange(Node target) {
        if (target != this) {
            textureInvalidated = true;
            if (autoResizedMesh) {
                if (initialized && createSimpleMesh()) {
//                    writefln("%s: reset texture", name);
                    initialized = false;
                }
            }
        }
        super.notifyChange(target);
    }

    override
    void rebuffer(ref MeshData data) {
        if (data.vertices.length == 0) {
//            writefln("enable auto resize %s", name);
            autoResizedMesh = true;
        } else {
//            writefln("disable auto resize %s", name);
            autoResizedMesh = false;
        }

        super.rebuffer(data);
        initialized = false;
        setIgnorePuppet(false);
        notifyChange(this);
    }
}