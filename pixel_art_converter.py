from PIL import Image


def start():

    file_name = input("Input a file name: ")
    image = Image.open(file_name, "r")

    x = int(input("Input your width dimensions (eg, 256): "))
    unit_size = int(input("Input your unit size (eg, 4): "))
  
    colours = image.getcolors()

    colour_to_register = {}

    base_address = input("Input the base display register: ")

    for colour in colours:

        if (colour[1][3] != 255):
            continue

        register_name = input(f"Input the register to use for colour, {colour[1]}, in format $register: ")

        colour_to_register[colour[1]] = register_name

    pixels_list = list(image.getdata())
    width, height = image.size
    pixels = [pixels_list[i * width:(i + 1) * width] for i in range(height)]

    with open(f"{file_name}.txt", "w") as output_file:

        for colour in colour_to_register.keys():

            register = colour_to_register[colour]

            r = hex(colour[0]).split("x")[1]

            if r == "0":
                r = "00"

            g = hex(colour[1]).split("x")[1]

            if g == "0":
                g = "00"

            b = hex(colour[2]).split("x")[1]

            if b == "0":
                b = "00"

            colour_hex = f"0x00{r}{g}{b}"
            set_string = f"        li {register}, {colour_hex}"
            print(set_string)
            output_file.write(f"{set_string}\n")

        for i in range(len(pixels)):

            row = pixels[i]

            for j in range(len(row)):

                pixel = row[j]

                if pixel[3] != 255:
                    continue

                unit_cell = i * x + j * unit_size

                register_type = colour_to_register[pixel]

                write_to_buffer_string = f"        sw {register_type}, {unit_cell}({base_address})"
                print(write_to_buffer_string)
                output_file.write(f"{write_to_buffer_string}\n")

    print(f"Width: {width}, Height: {height}")



if __name__ == "__main__":
    start()
