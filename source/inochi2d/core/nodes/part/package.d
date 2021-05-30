/*
    Inochi2D Part

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.part;
import inochi2d.fmt.serialize;
import inochi2d.core.nodes.drawable;
import inochi2d.core;
import inochi2d.math;
import bindbc.opengl;
import std.exception;
import std.algorithm.mutation : copy;

public import inochi2d.core.meshdata;


package(inochi2d) {
    private {
        Shader partShader;
        Shader partMaskShader;
    }

    void inInitPart() {
        inRegisterNodeType!Part;
        partShader = new Shader(import("basic/basic.vert"), import("basic/basic.frag"));
        partMaskShader = new Shader(import("basic/basic.vert"), import("basic/basic-mask.frag"));
    }
}


/**
    Creates a simple part that is sized after the texture given
    part is created based on file path given.
    Supported file types are: png, tga and jpeg

    This is unoptimal for normal use and should only be used
    for real-time use when you want to add/remove parts on the fly
*/
Part inCreateSimplePart(string file, Node parent = null) {
    return inCreateSimplePart(ShallowTexture(file), parent, file);
}

/**
    Creates a simple part that is sized after the texture given

    This is unoptimal for normal use and should only be used
    for real-time use when you want to add/remove parts on the fly
*/
Part inCreateSimplePart(ShallowTexture texture, Node parent = null, string name = "New Part") {
	Texture tex = new Texture(texture);
	MeshData data = MeshData([
		vec2(-(tex.width/2), -(tex.height/2)),
		vec2(-(tex.width/2), tex.height/2),
		vec2(tex.width/2, -(tex.height/2)),
		vec2(tex.width/2, tex.height/2),
	], 
	[
		vec2(0, 0),
		vec2(0, 1),
		vec2(1, 0),
		vec2(1, 1),
	], 
	[
		0, 1, 2,
		2, 1, 3
	]);
	Part p = new Part(data, [tex], parent);
	p.name = name;
    return p;
}

/**
    Masking mode
*/
enum MaskingMode {

    /**
        The part should be masked by the drawables specified
    */
    Mask,

    /**
        The path should be dodge masked by the drawables specified
    */
    DodgeMask
}

/**
    Dynamic Mesh Part
*/
@TypeId("Part")
class Part : Drawable {
private:

    /* current texture */
    size_t currentTexture = 0;
    
    GLuint uvbo;

    /* GLSL Uniforms (Normal) */
    GLint mvp;
    GLint gopacity;

    /* GLSL Uniforms (Masks) */
    GLint mmvp;
    GLint mthreshold;
    GLint mgopacity;

    uint[] pendingMasks;

    void updateUVs() {
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glBufferData(GL_ARRAY_BUFFER, data.uvs.length*vec2.sizeof, data.uvs.ptr, GL_STATIC_DRAW);
    }

    /*
        RENDERING
    */

    void drawSelf(bool isMask = false)() {

        // Bind the vertex array
        this.bindVertexArray();

        static if (isMask) {
            partMaskShader.use();
            partMaskShader.setUniform(mmvp, inGetCamera().matrix * transform.matrix());
            partMaskShader.setUniform(mthreshold, maskAlphaThreshold);
            partMaskShader.setUniform(mgopacity, opacity);
        } else {
            partShader.use();
            partShader.setUniform(mvp, inGetCamera().matrix * transform.matrix());
            partShader.setUniform(gopacity, opacity);
        }

        // Bind the texture
        textures[currentTexture].bind();

        // Enable points array
        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Enable UVs array
        glEnableVertexAttribArray(1); // uvs
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Bind index buffer
        this.bindIndex();

        // Disable the vertex attribs after use
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
    }

protected:
    override
    void renderMask() {
        
        // Enable writing to stencil buffer and disable writing to color buffer
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
        glStencilFunc(GL_ALWAYS, 1, 0xFF);
        glStencilMask(0xFF);

        // Draw ourselves to the stencil buffer
        drawSelf!true();

        // Disable writing to stencil buffer and enable writing to color buffer
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    }

    override
    string typeId() { return "Part"; }

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelf(ref InochiSerializer serializer) {
        super.serializeSelf(serializer);
        
        serializer.putKey("textures");
        auto state = serializer.arrayBegin();
            serializer.elemBegin;
            serializer.putValue(name);
        serializer.arrayEnd(state);

        if (mask.length > 0) {

            serializer.putKey("mask_mode");
            serializer.serializeValue(maskingMode);

            serializer.putKey("mask_threshold");
            serializer.putValue(maskAlphaThreshold);

            serializer.putKey("masked_by");
            state = serializer.arrayBegin();
                foreach(m; mask) {
                    serializer.elemBegin;
                    serializer.putValue(m.uuid);
                }
            serializer.arrayEnd(state);
        }

        serializer.putKey("opacity");
        serializer.putValue(opacity);
    }

    /**
        Allows serializing self data (with compact serializer)
    */
    override
    void serializeSelf(ref InochiSerializerCompact serializer) {
        super.serializeSelf(serializer);
        
        serializer.putKey("textures");
        auto state = serializer.arrayBegin();
            serializer.elemBegin;
            serializer.putValue(name);
        serializer.arrayEnd(state);

        serializer.putKey("mask_mode");
        serializer.serializeValue(maskingMode);

        serializer.putKey("mask_threshold");
        serializer.putValue(maskAlphaThreshold);

        if (mask.length > 0) {

            serializer.putKey("masked_by");
            state = serializer.arrayBegin();
                foreach(m; mask) {
                    serializer.elemBegin;
                    serializer.putValue(m.uuid);
                }
            serializer.arrayEnd(state);
        }

        serializer.putKey("opacity");
        serializer.putValue(opacity);

    }

    override
    SerdeException deserializeFromAsdf(Asdf data) {
        super.deserializeFromAsdf(data);

        // TODO: Index textures by ID
        string texName;
        auto elements = data["textures"].byElement;
        if (!elements.empty) {
            if (auto exc = elements.front.deserializeValue(texName)) return exc;
            this.textures = [new Texture(texName)];
        }

        data["opacity"].deserializeValue(this.opacity);

        if (!data["masked_by"].isEmpty) {
            data["mask_mode"].deserializeValue(this.maskingMode);
            data["mask_threshold"].deserializeValue(this.maskAlphaThreshold);

            // Go every masked part
            foreach(imask; data["masked_by"].byElement) {
                uint uuid;
                if (auto exc = imask.deserializeValue(uuid)) return exc;
                this.pendingMasks ~= uuid;
            }
        }

        // Update indices and vertices
        this.updateUVs();
        return null;
    }

public:
    /**
        List of textures this part can use
    */
    Texture[] textures;

    /**
        A part this part should "dodge"
    */
    Drawable[] mask;

    /**
        Masking mode
    */
    MaskingMode maskingMode = MaskingMode.Mask;
    
    /**
        Alpha Threshold for the masking system, the higher the more opaque pixels will be discarded in the masking process
    */
    float maskAlphaThreshold = 0.01;

    /**
        Opacity of the mesh
    */
    float opacity = 1;

    /**
        Gets the active texture
    */
    Texture activeTexture() {
        return textures[currentTexture];
    }

    /**
        Constructs a new part
    */
    this(MeshData data, Texture[] textures, Node parent = null) {
        this(data, textures, inCreateUUID(), parent);
    }

    /**
        Constructs a new part
    */
    this(Node parent = null) {
        super(parent);
        glGenBuffers(1, &uvbo);

        mvp = partShader.getUniformLocation("mvp");
        gopacity = partShader.getUniformLocation("opacity");
        
        mmvp = partMaskShader.getUniformLocation("mvp");
        mthreshold = partMaskShader.getUniformLocation("threshold");
        mgopacity = partMaskShader.getUniformLocation("opacity");
    }

    /**
        Constructs a new part
    */
    this(MeshData data, Texture[] textures, uint uuid, Node parent = null) {
        super(data, uuid, parent);
        this.textures = textures;
        glGenBuffers(1, &uvbo);

        mvp = partShader.getUniformLocation("mvp");
        gopacity = partShader.getUniformLocation("opacity");
        
        mmvp = partMaskShader.getUniformLocation("mvp");
        mthreshold = partMaskShader.getUniformLocation("threshold");
        mgopacity = partMaskShader.getUniformLocation("opacity");
        this.updateUVs();
    }
    
    override
    void rebuffer(MeshData data) {
        super.rebuffer(data);
        this.updateUVs();
    }

    override
    void drawOne() {
        if (!enabled) return;
        if (opacity == 0) return; // Might as well save the trouble
        
        glUniform1f(mthreshold, maskAlphaThreshold);
        glUniform1f(mgopacity, opacity);
        
        if (mask.length > 0) {
            inBeginMask();

            foreach(drawable; mask) {
                drawable.renderMask();
            }

            // Begin drawing content
            if (maskingMode == MaskingMode.Mask) inBeginMaskContent();
            else inBeginDodgeContent();
            
            // We are the content
            this.drawSelf();

            inEndMask();
            return;
        }

        this.drawSelf();
        super.drawOne();
    }

    override
    void draw() {
        if (!enabled) return;
        this.drawOne();

        foreach(child; children) {
            child.draw();
        }
    }

    override
    void finalize() {
        super.finalize();
        foreach(pmask; pendingMasks) {
            if (Node nMask = puppet.find!Drawable(pmask)) {
                mask ~= cast(Drawable)nMask;
            }
        }
        pendingMasks.length = 0;
    }
}