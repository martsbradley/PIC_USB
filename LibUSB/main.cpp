#include <iostream>
#include <libusb.h>
#include <usb.h>
#include <unistd.h>
#include <iostream>
#include <string>
#include <string.h>
#include <math.h>

using namespace std;

void printdev(libusb_device *dev); //prototype of the function
libusb_device_handle* claimInterface(libusb_device_handle *dev_handle);
void resetDevice(libusb_device_handle* dev_handle);
void printDetails(libusb_context *ctx);
libusb_device_handle* getDeviceHandle(libusb_context *ctx);
libusb_device_handle* setConfiguration(libusb_device_handle* dev_handle);

void showError(int result) {
        switch(result) {
        case LIBUSB_ERROR_TIMEOUT:
            cout << "The transfer timed out " << endl;
            break;
        case LIBUSB_ERROR_PIPE :
            cout << "The endpoint halted " << endl;
            break;
        case LIBUSB_ERROR_OVERFLOW :
            cout << "The device offered more data, see Packets and overflows " << endl;
            break;
        case LIBUSB_ERROR_NO_DEVICE :
            cout << "The device has been disconnected " << endl;
            break;
        case LIBUSB_ERROR_BUSY :
            cout << "if called from event handling context " << endl;
            break;
        default:
            cout << "Other error with code (" << result << ")" << endl;
        };
}


libusb_device_handle* setConfiguration(libusb_device_handle* dev_handle) {

    int activeConfiguration = 1;
    int configSetResult = libusb_set_configuration (dev_handle, activeConfiguration);       

    switch (configSetResult) {
        case 0:
            cout << "Set config " << configSetResult << endl;
            break;
        case LIBUSB_ERROR_NOT_FOUND:
            cout << "requested configuration does not exist" << endl;
            return 0;
            break;
        case LIBUSB_ERROR_BUSY:
            cout << "interfaces are currently claimed " << endl;
            return 0;
            break;
        case LIBUSB_ERROR_NO_DEVICE:
            cout << "device has been disconnected" << endl;
            return 0;
            break;
        default:
            cout << "Undefined errror setting the configuration " << endl;
            return 0;
    };
    cout << "setConfiguration" << endl;
    return dev_handle;
}

libusb_device_handle* getDeviceHandle(libusb_context *ctx) {
    //cout << "getDeviceHandle" << endl;
    libusb_device_handle *dev_handle = libusb_open_device_with_vid_pid(ctx, 1240, 20);

    if(libusb_kernel_driver_active(dev_handle, 0) == 1)  //find out if kernel driver is attached
    {
        cout<<"Kernel Driver Active"<<endl;

        if(libusb_detach_kernel_driver(dev_handle, 0) == 0) //detach it
        {
          cout<<"Kernel Driver Detached!"<<endl;
	}
    }

    if (!dev_handle) {
        cout << "dev_handle is null" << endl;
    }
    return dev_handle;
}


libusb_device_handle* claimInterface(libusb_device_handle *dev_handle) {

    int result = libusb_claim_interface(dev_handle, 0);
    if (result != 0) {
	cout<<"Cannot Claim Interface"<<endl;
        switch (result) {
            case LIBUSB_ERROR_NOT_FOUND: 
                cout << "requested interface does not exist " << endl;
                break;
            case LIBUSB_ERROR_BUSY: 
                cout << "another program or driver has claimed the interface"  << endl;
                break;
            case LIBUSB_ERROR_NO_DEVICE: 
                cout << "The device has been disconnected" << endl;
                break;
            default:
                cout << "Other error with code (" << result << ")" << endl;
        };
	return 0;
    }
    else if (result == 0 ) {
        cout<<"Claimed interface" << endl;
    }
    return dev_handle;
}

void resetDevice(libusb_device_handle* dev_handle) {
    libusb_reset_device(dev_handle); 
}



int interruptTransferOut(libusb_device_handle* dev_handle, unsigned char *data) {

    unsigned int timeout = 1000;

    int transferred = 0;
    unsigned char endpointId = 1 |LIBUSB_ENDPOINT_OUT;
    int result = libusb_interrupt_transfer(dev_handle,
                                           endpointId,
                                           data,
                                           8,
                                           &transferred,
                                           timeout);
    if (result == 0) {
        //cout << "success: Transferred bytes " << transferred << endl;
    } 
    else {
        switch(result) {
        case LIBUSB_ERROR_TIMEOUT:
            cout << "The transfer timed out " << endl;
            break;
        case LIBUSB_ERROR_PIPE :
            cout << "The endpoint halted " << endl;
            break;
        case LIBUSB_ERROR_OVERFLOW :
            cout << "The device offered more data, see Packets and overflows " << endl;
            break;
        case LIBUSB_ERROR_NO_DEVICE :
            cout << "The device has been disconnected " << endl;
            break;
        case LIBUSB_ERROR_BUSY :
            cout << "if called from event handling context " << endl;
            break;
        default:
            cout << "Other error with code (" << result << ")" << endl;
        };
    }

    return result;

}

void printDetails(libusb_context *ctx) {

    libusb_device **devs; //pointer to pointer of device, used to retrieve a list of devices

    ssize_t cnt = libusb_get_device_list(ctx, &devs); //get the list of devices

    if(cnt < 0) {
        cout<<"Get Device Error"<<endl; //there was an error
    }
    cout<<cnt<<" Devices in list."<<endl; //print total number of usb devices

    ssize_t i; //for iterating through the list

    for(i = 0; i < cnt; i++) 
    {   
	printdev(devs[i]); //print specs of this device
    }

    libusb_free_device_list(devs, 1); //free the list, unref the devices in it
    
    cout << "freed device list " << endl;
}

void printdev(libusb_device *dev) 
{
    libusb_device_descriptor desc;
    int result = libusb_get_device_descriptor(dev, &desc);
    if (result < 0) {
        cout<<"failed to get device descriptor"<<endl;
        return;
    }
    if (!(desc.idVendor == 0x4d8 && desc.idProduct == 0x14)) return;
    cout << endl << "++++++++++++++++++++++" << endl;

    cout<<"Number of possible configurations: "<<(int)desc.bNumConfigurations<< endl;
    cout<<"Device Class: "<<(int)desc.bDeviceClass<< endl;
    cout<<"VendorID: "<<desc.idVendor<< endl;
    cout<<"ProductID: "<<desc.idProduct<<endl;
    libusb_config_descriptor *config;
    libusb_get_config_descriptor(dev, 0, &config);
    cout<<"Interfaces: "<<(int)config->bNumInterfaces<< endl;
    const libusb_endpoint_descriptor *epdesc;

    for(int i=0; i<(int)config->bNumInterfaces; i++) 
    {
        const libusb_interface *inter = &config->interface[i];
        cout<<"\tNumber of alternate settings: "<<inter->num_altsetting<< endl;
        for(int j=0; j<inter->num_altsetting; j++) 
        {
            const libusb_interface_descriptor *interdesc = &inter->altsetting[j];

            cout<<"\tInterface Number: "<<(int)interdesc->bInterfaceNumber<< endl;
            cout<<"\tNumber of endpoints: "<<(int)interdesc->bNumEndpoints<< endl;
            for(int k=0; k < (int) interdesc->bNumEndpoints; k++) 
            {
                epdesc = &interdesc->endpoint[k];
                cout<<"\tDescriptor Type: "<<(int)epdesc->bDescriptorType<< endl;
                cout<<"\tEP Address: "<<(int)epdesc->bEndpointAddress<< endl;
            }
        }
    }

    cout<<endl;





    libusb_free_config_descriptor(config);
}

void interruptInToComputerTransfer(libusb_device_handle* dev_handle) {
    unsigned char *data = new unsigned char[10];      //data to write
    data[0]='\0';
    data[1]='\0';
    data[2]='\0';
    data[3]='\0';
    data[4]='\0';
    data[5]='\0';
    data[6]='\0';
    data[7]='\0'; 
    data[8]='\0'; 
    data[9]='\0'; 

    unsigned char endpointId = 2 |LIBUSB_ENDPOINT_IN;
    unsigned int timeout = 500;
    int transferred = 0;

    int result = libusb_interrupt_transfer(dev_handle,
                                       endpointId,
                                       data,
                                       8,
                                       &transferred,
                                       timeout);
    if (result == 0) {
        cout << "Transferred bytes: "  << transferred << endl;
        cout <<                 data[0] << endl;
        cout <<                 data[1] << endl;
        cout <<                 data[2] << endl;
        cout <<                 data[3] << endl;
        cout <<                 data[4] << endl;
        cout <<                 data[5] << endl;
        cout <<                 data[6] << endl;
        cout <<                 data[7] << endl;
    }
    else {
        showError(result);
    }
}

int main() 
{
    libusb_context *ctx = NULL; //a libusb session
    int result = libusb_init(&ctx); //initialize a library session
    if(result < 0) {
        cout<<"Init Error "<< result <<endl; //there was an error
                return 1;
    }

    libusb_set_debug(ctx, 3); //set verbosity level to 3, as suggested in the documentation
    // Below is on my newer copy of LibUSB on the laptop.
    //libusb_set_option(ctx, LIBUSB_OPTION_LOG_LEVEL, LIBUSB_LOG_LEVEL_DEBUG);
    //                       //LIBUSB_LOG_LEVEL_NONE = 0
    //                       //LIBUSB_LOG_LEVEL_ERROR = 1
    //                       //LIBUSB_LOG_LEVEL_WARNING = 2
    //                       //LIBUSB_LOG_LEVEL_INFO = 3
    //                       //LIBUSB_LOG_LEVEL_DEBUG = 4;

    //printDetails(ctx);

    libusb_device_handle* dev_handle = getDeviceHandle(ctx);

    dev_handle = setConfiguration(dev_handle);

    dev_handle = claimInterface(dev_handle);

    unsigned char *data = new unsigned char[10];      //data to write
    data[0]='M';
    data[1]='a';
    data[2]='r';
    data[3]='t';
    data[4]='y';
    data[5]='\r';
    data[6]='\n';
    data[7]='\0'; 
    
    if (dev_handle) {
        int result = -1;

        snprintf((char*)data, 8, "M___%d\r\n",1);
        result = interruptTransferOut(dev_handle,data);
        snprintf((char*)data, 8, "M___%d\r\n",2);
        result = interruptTransferOut(dev_handle,data);
        snprintf((char*)data, 8, "M___%d\r\n",3);
        result = interruptTransferOut(dev_handle,data);
        snprintf((char*)data, 8, "M___%d\r\n",4);
        result = interruptTransferOut(dev_handle,data);
        snprintf((char*)data, 8, "M___%d\r\n",5);
        result = interruptTransferOut(dev_handle,data);
        snprintf((char*)data, 8, "M___%d\r\n",6);
        result = interruptTransferOut(dev_handle,data);
        snprintf((char*)data, 8, "M___%d\r\n",7);
        result = interruptTransferOut(dev_handle,data);
        snprintf((char*)data, 8, "M___%d\r\n",8);
        result = interruptTransferOut(dev_handle,data);
        snprintf((char*)data, 8, "M___%d\r\n",9);
        result = interruptTransferOut(dev_handle,data);
        snprintf((char*)data, 8, "M___%c\r\n",'x');
        result = interruptTransferOut(dev_handle,data);
        snprintf((char*)data, 8, "M___%c\r\n",'y');
        result = interruptTransferOut(dev_handle,data);
        snprintf((char*)data, 8, "M___%c\r\n",'z');
        result = interruptTransferOut(dev_handle,data);



        //read input chars into a buffer
        //send the buffer to the USB
        //


        string mystr;
        const char *newLine = "\r\n";
        cout << "Send some data, ctrl-c to finish:" << endl;
        while (getline (cin, mystr) ) {
            cout << mystr << endl;

            while (mystr.length() > 0) {

                memset(&data[0], 0, 8);

                memcpy(&data[0],mystr.c_str(), 8);

                int length = mystr.length();
                mystr.erase(0, min(8, length));

                result = interruptTransferOut(dev_handle,data);
            }


            memset(&data[0],0,8);
            strncpy((char*)&data[0], newLine, 2);
            
            result = interruptTransferOut(dev_handle,data);

        }

        cout << "Read one ..." << endl;
        interruptInToComputerTransfer(dev_handle);
        cout << "Read two ..." << endl;
        interruptInToComputerTransfer(dev_handle);
        cout << "Read three ..." << endl;
        interruptInToComputerTransfer(dev_handle);




        libusb_close(dev_handle); 
    }

    libusb_exit(ctx); //close the session
    return 0;
}
